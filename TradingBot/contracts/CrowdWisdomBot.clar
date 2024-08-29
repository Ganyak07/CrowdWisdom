;; CrowdWisdomBot.clar
;; Enhanced with weighted voting based on stake amounts

;; Define constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-enough-funds (err u101))
(define-constant err-no-stake (err u102))
(define-constant err-invalid-vote (err u103))

;; Define data variables
(define-data-var ai-decision (string-utf8 10) u"hold")
(define-data-var total-staked uint u0)

;; Define data maps
(define-map user-stakes principal uint)
(define-map user-votes principal (string-utf8 10))
(define-map vote-totals (string-utf8 10) uint)

;; Public functions

;; Stake Bitcoin to participate in voting
(define-public (stake-bitcoin (amount uint))
    (let ((current-stake (default-to u0 (map-get? user-stakes tx-sender))))
        (if (>= (stx-get-balance tx-sender) amount)
            (begin
                (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
                (map-set user-stakes tx-sender (+ current-stake amount))
                (var-set total-staked (+ (var-get total-staked) amount))
                (ok true))
            err-not-enough-funds)))

;; Vote on AI decision with weight based on stake
(define-public (vote (decision (string-utf8 10)))
    (let 
        (
            (user-stake (default-to u0 (map-get? user-stakes tx-sender)))
            (previous-vote (default-to u"none" (map-get? user-votes tx-sender)))
        )
        (asserts! (> user-stake u0) err-no-stake)
        (asserts! (or (is-eq decision u"buy") (is-eq decision u"sell") (is-eq decision u"hold")) err-invalid-vote)
        (if (not (is-eq previous-vote u"none"))
            (map-set vote-totals previous-vote (- (default-to u0 (map-get? vote-totals previous-vote)) user-stake))
        )
        (map-set user-votes tx-sender decision)
        (map-set vote-totals decision (+ (default-to u0 (map-get? vote-totals decision)) user-stake))
        (ok true)))

;; Get current AI decision
(define-read-only (get-ai-decision)
    (ok (var-get ai-decision)))

;; Get total staked amount
(define-read-only (get-total-staked)
    (ok (var-get total-staked)))

;; Get user stake
(define-read-only (get-user-stake (user principal))
    (ok (default-to u0 (map-get? user-stakes user))))

;; Get user vote
(define-read-only (get-user-vote (user principal))
    (ok (default-to u"none" (map-get? user-votes user))))

;; Get vote total for a decision
(define-read-only (get-vote-total (decision (string-utf8 10)))
    (ok (default-to u0 (map-get? vote-totals decision))))

;; Admin function to update AI decision
(define-public (update-ai-decision (new-decision (string-utf8 10)))
    (if (is-eq tx-sender contract-owner)
        (begin
            (var-set ai-decision new-decision)
            (ok true))
        err-owner-only))

;; Initialize contract
(begin
    (var-set ai-decision u"hold")
    (var-set total-staked u0))