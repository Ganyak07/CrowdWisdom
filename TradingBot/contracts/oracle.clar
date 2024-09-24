;; Oracle Contract to store and update market data
;; The AI model or some external source feeds the data into this contract

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))

;; Data variables
(define-data-var latest-market-data uint u0)
(define-data-var last-updated uint u0)

;; Functions

(define-public (update-market-data (new-data uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set latest-market-data new-data)
    (var-set last-updated (block-height))
    (ok true)
  )
)

(define-read-only (get-latest-market-data)
  (ok {data: (var-get latest-market-data), last-updated: (var-get last-updated)})
)
