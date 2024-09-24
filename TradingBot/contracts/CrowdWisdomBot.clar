;; CrowdWisdomBot.clar
;; Enhanced with additional features and AI integration

;; Define constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-enough-funds (err u101))
(define-constant err-no-stake (err u102))
(define-constant err-invalid-vote (err u103))
(define-constant err-unstake-too-soon (err u104))
(define-constant err-insufficient-stake (err u105))
(define-constant err-oracle-failed (err u106))
(define-constant minimum-confidence uint u70) ;; Minimum confidence level (70%)
(define-constant decision-expiry uint u144) ;; Decision expiry time (approximately 24 hours in blocks)

;; Define data variables
(define-data-var ai-decision (string-utf8 10) u"hold")
(define-data-var total-staked uint u0)
(define-data-var min-stake-amount uint u1000000) ;; Minimum stake amount (e.g., 1 STX)
(define-data-var unstake-lock-period uint u144) ;; Lock period for unstaking (e.g., 1 day in blocks)

;; Define data maps
(define-map user-stakes 
    principal 
    { amount: uint, last-stake-block: uint })
(define-map user-votes principal (string-utf8 10))
(define-map vote-totals (string-utf8 10) uint)
(define-map user-rewards principal uint)

;; Public functions

;; Stake STX to participate in voting
(define-public (stake-stx (amount uint))
    (let (
        (current-stake (default-to { amount: u0, last-stake-block: u0 } (map-get? user-stakes tx-sender)))
        (new-stake-amount (+ (get amount current-stake) amount))
    )
        (asserts! (>= amount (var-get min-stake-amount)) err-insufficient-stake)
        (asserts! (>= (stx-get-balance tx-sender) amount) err-not-enough-funds)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set user-stakes tx-sender 
            { amount: new-stake-amount, last-stake-block: block-height })
        (var-set total-staked (+ (var-get total-staked) amount))
        (ok true)
    )
)

;; Unstake STX
(define-public (unstake-stx (amount uint))
    (let (
        (current-stake (default-to { amount: u0, last-stake-block: u0 } (map-get? user-stakes tx-sender)))
        (stake-amount (get amount current-stake))
        (last-stake-block (get last-stake-block current-stake))
    )
        (asserts! (>= stake-amount amount) err-insufficient-stake)
        (asserts! (>= (- block-height last-stake-block) (var-get unstake-lock-period)) err-unstake-too-soon)
        (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
        (map-set user-stakes tx-sender 
            { amount: (- stake-amount amount), last-stake-block: last-stake-block })
        (var-set total-staked (- (var-get total-staked) amount))
        (ok true)
    )
)

;; Vote on AI decision with weight based on stake
(define-public (vote (decision (string-utf8 10)))
    (let 
        (
            (user-stake (get amount (default-to { amount: u0, last-stake-block: u0 } (map-get? user-stakes tx-sender))))
            (previous-vote (default-to u"none" (map-get? user-votes tx-sender)))
        )
        (asserts! (> user-stake u0) err-no-stake)
        (asserts! (or (is-eq decision u"buy") (is-eq decision u"sell") (is-eq decision u"hold")) err-invalid-vote)
        (if (not (is-eq previous-vote u"none"))
            (map-set vote-totals previous-vote (- (default-to u0 (map-get? vote-totals previous-vote)) user-stake))
        )
        (map-set user-votes tx-sender decision)
        (map-set vote-totals decision (+ (default-to u0 (map-get? vote-totals decision)) user-stake))
        (ok true)
    )
)

;; Claim rewards
(define-public (claim-rewards)
    (let ((user-reward (default-to u0 (map-get? user-rewards tx-sender))))
        (asserts! (> user-reward u0) err-not-enough-funds)
        (try! (as-contract (stx-transfer? user-reward tx-sender tx-sender)))
        (map-set user-rewards tx-sender u0)
        (ok user-reward)
    )
)

;; Update AI decision from Oracle
(define-public (update-ai-decision)
  (let (
    (oracle-data (unwrap! (contract-call? .Oracle get-latest-decision) err-oracle-failed))
    (new-decision (get decision oracle-data))
    (confidence (get confidence oracle-data))
    (last-update (get last-update oracle-data))
  )
    (asserts! (>= confidence minimum-confidence) err-oracle-failed)
    (asserts! (< (- block-height last-update) decision-expiry) err-oracle-failed)
    (var-set ai-decision new-decision)
    (ok true)
  )
)

;; Admin function to distribute rewards
(define-public (distribute-rewards (reward-pool uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (let (
            (correct-votes (default-to u0 (map-get? vote-totals (var-get ai-decision))))
            (reward-per-token (if (> correct-votes u0) (/ reward-pool correct-votes) u0))
        )
            (map-set vote-totals u"buy" u0)
            (map-set vote-totals u"sell" u0)
            (map-set vote-totals u"hold" u0)
            (ok true)
        )
    )
)

;; Getter functions

(define-read-only (get-ai-decision)
    (ok (var-get ai-decision)))

(define-read-only (get-ai-decision-with-metadata)
  (let ((oracle-data (unwrap! (contract-call? .Oracle get-latest-decision) err-oracle-failed)))
    (ok {
      decision: (var-get ai-decision),
      confidence: (get confidence oracle-data),
      last-update: (get last-update oracle-data)
    })
  )
)

(define-read-only (get-total-staked)
    (ok (var-get total-staked)))

(define-read-only (get-user-stake (user principal))
    (ok (get amount (default-to { amount: u0, last-stake-block: u0 } (map-get? user-stakes user)))))

(define-read-only (get-user-vote (user principal))
    (ok (default-to u"none" (map-get? user-votes user))))

(define-read-only (get-vote-total (decision (string-utf8 10)))
    (ok (default-to u0 (map-get? vote-totals decision))))

(define-read-only (get-user-rewards (user principal))
    (ok (default-to u0 (map-get? user-rewards user))))

(define-read-only (get-min-stake-amount)
    (ok (var-get min-stake-amount)))

(define-read-only (get-unstake-lock-period)
    (ok (var-get unstake-lock-period)))

;; Admin functions

(define-public (set-min-stake-amount (new-amount uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set min-stake-amount new-amount)
        (ok true)
    )
)

(define-public (set-unstake-lock-period (new-period uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set unstake-lock-period new-period)
        (ok true)
    )
)

;; Initialize contract
(begin
    (var-set ai-decision u"hold")
    (var-set total-staked u0)
    (var-set min-stake-amount u1000000)
    (var-set unstake-lock-period u144)
)