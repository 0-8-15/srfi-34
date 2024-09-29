;;; SRFI-34: Exceptions for scheme

;;; This file contains the macros.  srfi-34-support.scm contains
;;; some support procedures needed at runtime.
       
;;; This is the reference implementation copied (almost) verbatim from
;;; http://srfi.schemers.org/srfi-34/srfi-34.html with rearranging and
;;; slight modifications to be a chicken egg.

(module srfi-34
   (with-exception-handlers
    with-exception-handler
    raise
    guard)

(import scheme)
(cond-expand
 (chicken-4
  (import
   (prefix (only chicken error) chicken:)
   (only chicken make-parameter)
   ))
 (chicken-5
  (import
   (prefix (only (chicken base) error) chicken:)
   srfi-39
   ))
 (else
  (import
    (prefix (only (chicken base) error) chicken:)
    (only (scheme base) make-parameter))
  ))

(define current-exception-handlers
 (make-parameter
  (list ##sys#current-exception-handler)))

(define (with-exception-handlers new-handlers thunk)
  (let ((previous-handlers (current-exception-handlers))
	 [oldh ##sys#current-exception-handler])
    (dynamic-wind
	 (lambda ()
	   (set! ##sys#current-exception-handler
             (if (null? new-handlers) oldh (car new-handlers)))
	   (current-exception-handlers new-handlers))
	 thunk
	 (lambda ()
	   (set! ##sys#current-exception-handler oldh)
	   (current-exception-handlers previous-handlers)))))

(define (with-exception-handler handler thunk)
  (with-exception-handlers (cons handler (current-exception-handlers))
                           thunk))

(set! chicken:with-exception-handler with-exception-handler)

(define (raise obj)
  (let ((handlers (current-exception-handlers)))
    (with-exception-handlers (cdr handlers)
      (lambda ()
        ((car handlers) obj)
        (chicken:error "handler returned"
               (car handlers)
               obj))))) 

;(require-extension ports)

(define-syntax guard
  (syntax-rules ()
    ((guard (var clause ...) e1 e2 ...)
     ((call-with-current-continuation
       (lambda (guard-k)
         (with-exception-handler
           (lambda (condition)
	     ((call-with-current-continuation
	       (lambda (handler-k)
                 (guard-k
                  (lambda ()
                    (let ((var condition))      ; clauses may SET! var
                      (guard-aux (handler-k (lambda ()
                                              (raise condition)))
                                 clause ...))))))))
           (lambda ()
	     (call-with-values
		 (lambda () e1 e2 ...)
	       (lambda args
		 (guard-k (lambda ()
			    (apply values args)))))))))))))


(define-syntax guard-aux
  (syntax-rules (else =>)
    ((guard-aux reraise (else result1 result2 ...))
     (begin result1 result2 ...))
    ((guard-aux reraise (test => result))
     (let ((temp test))
       (if temp 
           (result temp)
           reraise)))
    ((guard-aux reraise (test => result) clause1 clause2 ...)
     (let ((temp test))
       (if temp
           (result temp)
           (guard-aux reraise clause1 clause2 ...))))
    ((guard-aux reraise (test))
     test)
    ((guard-aux reraise (test) clause1 clause2 ...)
     (let ((temp test))
       (if temp
           temp
           (guard-aux reraise clause1 clause2 ...))))
    ((guard-aux reraise (test result1 result2 ...))
     (if test
         (begin result1 result2 ...)
         reraise))
    ((guard-aux reraise (test result1 result2 ...) clause1 clause2 ...)
     (if test
         (begin result1 result2 ...)
         (guard-aux reraise clause1 clause2 ...)))))

 )
