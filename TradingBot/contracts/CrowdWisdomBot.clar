;; CrowdWisdomBot.clar
;; Initial commit for AI-Driven Bitcoin Trading Bot with Crowd Wisdom

;; Define constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-enough-funds (err u101))
(define-constant err-no-vote (err u102))

;; Define data variables
(define-data-var ai-decision (string-utf8 10) u"hold")
(define-data-var total-staked uint u0)

;; Define data maps
(define-map user-stakes principal uint)
(define-map user-votes principal (string-utf8 10))

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

;; Vote on AI decision
(define-public (vote (decision (string-utf8 10)))
    (let ((user-stake (default-to u0 (map-get? user-stakes tx-sender))))
        (if (> user-stake u0)
            (begin
                (map-set user-votes tx-sender decision)
                (ok true))
            err-no-vote)))

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
    (ok (default-to "none" (map-get? user-votes user))))

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