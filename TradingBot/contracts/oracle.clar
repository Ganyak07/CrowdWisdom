;; Oracle.clar
;; This contract serves as a bridge between the off-chain AI model and the on-chain CrowdWisdomBot

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-decision (err u101))

(define-data-var latest-decision (string-utf8 10) u"hold")
(define-data-var decision-confidence uint u0)
(define-data-var last-update uint u0)

(define-public (update-decision (new-decision (string-utf8 10)) (confidence uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (or (is-eq new-decision u"buy") (is-eq new-decision u"sell") (is-eq new-decision u"hold")) err-invalid-decision)
    (var-set latest-decision new-decision)
    (var-set decision-confidence confidence)
    (var-set last-update block-height)
    (ok true)))

(define-read-only (get-latest-decision)
  (ok {
    decision: (var-get latest-decision),
    confidence: (var-get decision-confidence),
    last-update: (var-get last-update)
  }))

;; Initialize contract
(begin
  (var-set latest-decision u"hold")
  (var-set decision-confidence u0)
  (var-set last-update u0)
)