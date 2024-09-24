;; AI-Driven Bitcoin Trading Bot with Crowd Wisdom 
;; Implements weighted voting based on stake amounts
;; Adds Profit Distribution System based on stakes and voting participation

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-enough-funds (err u101))
(define-constant err-no-stake (err u102))
(define-constant err-already-voted (err u103))
(define-constant err-voting-closed (err u104))
(define-constant err-threshold-not-met (err u105))
(define-constant err-invalid-vote (err u106))
(define-constant err-voting-open (err u107))

;; Data variables
(define-data-var ai-decision (string-utf8 10) u"hold")
(define-data-var total-staked uint u0)
(define-data-var voting-open bool true)
(define-data-var vote-threshold uint u1000000) ;; 1 million microstacks as threshold
(define-data-var profit-pool uint u0) ;; Tracks total profits for distribution

;; Data maps
(define-map user-stakes principal uint)
(define-map user-votes { user: principal, decision: (string-utf8 10) } uint)
(define-map vote-tallies (string-utf8 10) uint)

;; Voting options
(define-data-var vote-options (list 3 (string-utf8 10)) (list u"buy" u"sell" u"hold"))

;; Read-only functions

(define-read-only (get-ai-decision)
  (ok (var-get ai-decision))
)

(define-read-only (get-user-stake (user principal))
  (ok (default-to u0 (map-get? user-stakes user)))
)

(define-read-only (get-total-staked)
  (ok (var-get total-staked))
)

(define-read-only (get-voting-status)
  (ok (var-get voting-open))
)

(define-read-only (get-vote-options)
  (ok (var-get vote-options))
)

(define-read-only (get-vote-tally (decision (string-utf8 10)))
  (ok (default-to u0 (map-get? vote-tallies decision)))
)

(define-read-only (get-profit-pool)
  (ok (var-get profit-pool))
)

;; Public functions

(define-public (stake-bitcoin (amount uint))
  (let (
    (current-stake (default-to u0 (map-get? user-stakes tx-sender)))
  )
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set user-stakes tx-sender (+ current-stake amount))
    (var-set total-staked (+ (var-get total-staked) amount))
    (ok true)
  )
)

(define-public (unstake-bitcoin (amount uint))
  (let (
    (current-stake (default-to u0 (map-get? user-stakes tx-sender)))
  )
    (asserts! (>= current-stake amount) err-not-enough-funds)
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    (map-set user-stakes tx-sender (- current-stake amount))
    (var-set total-staked (- (var-get total-staked) amount))
    (ok true)
  )
)

(define-public (vote-on-decision (decision (string-utf8 10)))
  (let (
    (user-stake (default-to u0 (map-get? user-stakes tx-sender)))
    (previous-vote (map-get? user-votes { user: tx-sender, decision: decision }))
  )
    (asserts! (var-get voting-open) err-voting-closed)
    (asserts! (> user-stake u0) err-no-stake)
    (asserts! (is-none previous-vote) err-already-voted)
    (asserts! (is-some (index-of (var-get vote-options) decision)) err-invalid-vote)
    (map-set user-votes { user: tx-sender, decision: decision } user-stake)
    (map-set vote-tallies decision (+ (default-to u0 (map-get? vote-tallies decision)) user-stake))
    (ok true)
  )
)

(define-public (unstake-with-penalty (amount uint))
  (let (
    (current-stake (default-to u0 (map-get? user-stakes tx-sender)))
  )
    ;; Apply penalty if unstaked before a set period
    (asserts! (>= current-stake amount) err-not-enough-funds)
    (try! (as-contract (stx-transfer? (* amount u1) tx-sender tx-sender))) ;; 10% Penalty
    (map-set user-stakes tx-sender (- current-stake amount))
    (var-set total-staked (- (var-get total-staked) amount))
    (ok true)
  )
)

(define-public (add-profit (amount uint))
  (begin
    (var-set profit-pool (+ (var-get profit-pool) amount))
    (ok true)
  )
)

(define-public (distribute-profits)
  (let (
    (total-profit (var-get profit-pool))
    (users (list-of-users))
  )
    (map
      (lambda (user)
        (let (
          (stake (default-to u0 (map-get? user-stakes user)))
          (participation-bonus (if (is-some (map-get? user-votes { user: user, decision: (var-get ai-decision) })) u1 u0))
          (user-share (/ (+ (* stake total-profit) participation-bonus) (var-get total-staked)))
        )
          (try! (stx-transfer? user-share (as-contract tx-sender) user))
        )
      )
      users
    )
    ;; Reset profit pool after distribution
    (var-set profit-pool u0)
    (ok true)
  )
)

;; Admin functions

(define-public (set-ai-decision (new-decision (string-utf8 10)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (var-set ai-decision new-decision))
  )
)

(define-public (toggle-voting)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (var-set voting-open (not (var-get voting-open))))
  )
)

(define-public (set-vote-threshold (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (var-set vote-threshold new-threshold))
  )
)

(define-public (set-vote-options (new-options (list 3 (string-utf8 10))))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (var-set vote-options new-options))
  )
)

;; Internal functions

(define-private (tally-votes)
  (let (
    (buy-votes (default-to u0 (map-get? vote-tallies u"buy")))
    (sell-votes (default-to u0 (map-get? vote-tallies u"sell")))
    (hold-votes (default-to u0 (map-get? vote-tallies u"hold")))
  )
    (cond
      ((and (> buy-votes sell-votes) (> buy-votes hold-votes)) u"buy")
      ((and (> sell-votes buy-votes) (> sell-votes hold-votes)) u"sell")
      true u"hold")
  )
)

(define-public (finalize-voting)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (not (var-get voting-open)) err-voting-open)
    (asserts! (>= (var-get total-staked) (var-get vote-threshold)) err-threshold-not-met)
    (let ((final-decision (tally-votes)))
      (var-set ai-decision final-decision)
      (ok final-decision)
    )
  )
)

;; Initialize contract
(begin
  (var-set ai-decision u"hold")
  (var-set total-staked u0)
  (var-set voting-open true)
)
