;; title: facility-licensing-and-inspections
;; version: 1.0.0
;; summary: Register facilities, manage license expirations, and record inspection results.
;; description: Simple, self-contained contract for kennel/daycare facility metadata and inspections. No cross-contract calls or traits.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Constants and errors
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define-constant ERR-NOT-FOUND (err u100))
(define-constant ERR-NOT-AUTHORIZED (err u101))
(define-constant ERR-ALREADY-REGISTERED (err u102))
(define-constant ERR-BAD-PARAMS (err u103))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Data vars
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define-data-var next-facility-id uint u1)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Data maps
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; facility-id => { owner, name, license-expiry, active, created-at }
(define-map facilities
  { id: uint }
  { owner: principal,
    name: (string-ascii 64),
    license-expiry: uint,
    active: bool,
    created-at: uint })

;; facility-id => number of inspections (used to generate per-facility inspection ids)
(define-map facility-inspection-counters
  { facility-id: uint }
  { next-inspection-id: uint })

;; keyed by (facility-id, inspection-id)
(define-map inspections
  { facility-id: uint, inspection-id: uint }
  { when: uint,                 ;; epoch seconds (or block-height substitute)
    score: uint,                ;; arbitrary score u0..u100
    outcome: (string-ascii 96), ;; short description of result
    inspector: principal })

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Helpers (private)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define-private (only-owner (facility-id uint))
  (match (map-get? facilities { id: facility-id })
    facility
    (if (is-eq (get owner facility) tx-sender)
        (ok true)
        ERR-NOT-AUTHORIZED)
    ERR-NOT-FOUND))

(define-private (get-next-inspection-id (facility-id uint))
  (let ((row (default-to { next-inspection-id: u1 }
                         (map-get? facility-inspection-counters { facility-id: facility-id }))))
    (ok (get next-inspection-id row))))

(define-private (bump-inspection-id (facility-id uint))
  (let ((row (default-to { next-inspection-id: u1 }
                         (map-get? facility-inspection-counters { facility-id: facility-id }))))
    (map-set facility-inspection-counters
             { facility-id: facility-id }
             { next-inspection-id: (+ u1 (get next-inspection-id row)) })
    (ok true)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Public entrypoints
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Register a facility. Returns newly assigned facility id.
(define-public (register-facility (name (string-ascii 64)) (license-expiry uint) (created-at uint))
  (begin
    (asserts! (> (len name) u0) ERR-BAD-PARAMS)
    (let ((new-id (var-get next-facility-id)))
      (map-set facilities
               { id: new-id }
               { owner: tx-sender,
                 name: name,
                 license-expiry: license-expiry,
                 active: true,
                 created-at: created-at })
      (var-set next-facility-id (+ new-id u1))
      (ok new-id))))

;; Update license-expiry for a facility (owner only)
(define-public (set-license-expiry (facility-id uint) (license-expiry uint))
  (begin
    (asserts! (is-ok (only-owner facility-id)) ERR-NOT-AUTHORIZED)
    (match (map-get? facilities { id: facility-id })
      facility
      (begin
        (map-set facilities { id: facility-id }
                 { owner: (get owner facility),
                   name: (get name facility),
                   license-expiry: license-expiry,
                   active: (get active facility),
                   created-at: (get created-at facility) })
        (ok true))
      ERR-NOT-FOUND)))

;; Enable/disable a facility (owner only)
(define-public (set-active (facility-id uint) (flag bool))
  (begin
    (asserts! (is-ok (only-owner facility-id)) ERR-NOT-AUTHORIZED)
    (match (map-get? facilities { id: facility-id })
      facility
      (begin
        (map-set facilities { id: facility-id }
                 { owner: (get owner facility),
                   name: (get name facility),
                   license-expiry: (get license-expiry facility),
                   active: flag,
                   created-at: (get created-at facility) })
        (ok flag))
      ERR-NOT-FOUND)))

;; Record an inspection (owner only). Returns inspection-id.
(define-public (record-inspection (facility-id uint)
                                 (when uint)
                                 (score uint)
                                 (outcome (string-ascii 96)))
  (begin
    (asserts! (is-ok (only-owner facility-id)) ERR-NOT-AUTHORIZED)
    (asserts! (<= score u100) ERR-BAD-PARAMS)
    (let ((next-id (unwrap! (get-next-inspection-id facility-id) ERR-BAD-PARAMS)))
      (map-set inspections { facility-id: facility-id, inspection-id: next-id }
               { when: when, score: score, outcome: outcome, inspector: tx-sender })
      (unwrap! (bump-inspection-id facility-id) ERR-BAD-PARAMS)
      (ok next-id))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Read-only entrypoints
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define-read-only (get-facility (facility-id uint))
  (map-get? facilities { id: facility-id }))

(define-read-only (is-facility-active (facility-id uint))
  (match (map-get? facilities { id: facility-id })
    data (ok (get active data))
    (ok false)))

(define-read-only (get-inspection (facility-id uint) (inspection-id uint))
  (map-get? inspections { facility-id: facility-id, inspection-id: inspection-id }))

(define-read-only (get-next-facility-id)
  (ok (var-get next-facility-id)))

(define-read-only (get-next-inspection-id-ro (facility-id uint))
  (unwrap-panic (get-next-inspection-id facility-id)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; End of file
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
