;;; srfi-34-examples.scm
;;;
;;; This file shows some examples of how this egg might be used.
;;;

(require-extension srfi-34)

;;; srfi-34 defines a list containing exception handler thunks. 
;;; This is what it is by default.
;;; (define *current-exception-handlers*
;;;  (list (lambda (condition)
;;;          (error "unhandled exception" condition))))
;;;
;;; The car of this list handles any exceptions raised.  Internally,
;;; this module uses dynamic-wind to maintain this list allowing you 
;;; to install exception handlers in the dynamic environment.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; ( raise obj ) 
;;; Passes obj, which is the exception, to the current exception handler
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

[when #f ;;; don't really do this, so we can see rest of examples
(begin
  (display "Doing some stuff...")(newline)
  (raise 'an-exception)
  (display "Won't get here.")(newline)) 
]

;;; This is what it prints if you change when #f to when #t
;Doing some stuff...
;Error: unhandled exception: an-exception
;
;        Call history:
;
;        <syntax>                (quote an-exception)
;        <syntax>                (display (quote "Won't get here."))
;        <syntax>                (quote "Won't get here.")
;        <syntax>                (begin (newline))
;        <syntax>                (newline)
;        <eval>          (display (quote "Doing some stuff..."))
;        <eval>          (newline)
;        <eval>          (raise (quote an-exception))    <--

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; guard
;;; guard is analogous to the try/catch syntax found in some other languages
;;; The catch part comes first, and then the body that is 'tried'. 
;;; It also includes => syntax for dealing with items extracted from thrown
;;; objects. 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; A vanilla example 

(guard ( e [(eq? e 'weird-exception)
	    (display "Caught a weird-exception")(newline)]
	   [(eq? e 'odd-exception)
	    (display "Caught an odd-exception")(newline)])
       (display "Doing some stuff")(newline)
       (raise 'weird-exception)
       (display "Won't get here")(newline) )

;;; This prints: 
; Doing some stuff
; Caught a weird-exception

;;; A vanilla example with an 'else' clause

(guard ( e [(eq? e 'weird-exception)
	    (display "Caught a weird-exception")(newline)]
	   [(eq? e 'odd-exception)
	    (display "Caught an odd-exception")(newline)]
	   [else (begin 
		   (display "Caught an unidentified flying exception: ")
		   (write e)(newline))])
       (display "Doing some stuff")(newline)
       (raise 'bizarre-exception)
       (display "Won't get here")(newline) )

;;; This prints:
; Doing some stuff
; Caught an unidentified flying exception: bizarre-exception

;;; Without the 'else' clause, the exception would go to the default exception 
;;; handler which would call 'error' and error-out printing that there was an 
;;; unhandled exception.  Else lets you easily do something different than 
;;; that for general exceptions.

;;; The => syntax
(guard (condition
         ((assq 'a condition) => cdr)
         ((assq 'b condition)))
  (raise (list (cons 'a 42))))
;=> 42

(guard (condition
         ((assq 'a condition) => cdr)
         ((assq 'b condition)))
  (raise (list (cons 'b 23))))
;=> (b . 23)


;;; Lower level stuff
;;; with-exception-handler

;;; Note: this procedure calls 'error' which doesn't return
(define my-exception-handler
  (lambda (e) 
    (error "my-exception-handler handled an exception:" e )) )

[when #f ;;; change this to when #t to make this execute for real
(with-exception-handler my-exception-handler 
  (lambda ()
    (display "Doing more stuff")(newline)
    (raise 'yet-another-exception)
    (display "Won't get here")(newline)))
]



;;; In the previous example,
;;; my-exception-handler does not return, but calls 'error' to abort the
;;; program.  In general you don't want to have all your exception handlers
;;; abort the program.  But they can't return either.  In the case where
;;; an exception is raised, execution has to pick up somewhere besides 
;;; the line immediately following the call to raise.  Where?  You need 
;;; to say where by calling that continuation inside your exception handler.

  
;;; This is an example of what NOT to do:
;;; The following exception handler is wrong because it returns control to 
;;; raise, which defeats the whole purpose of something called 'raise'.

(define my-WRONG-exception-handler
  (lambda (e) 
    (display "my-WRONG-exception-handler handled an exception: ")
    (write e)
    (newline)) )

[when #f  ;;; Don't really do this
(with-exception-handler my-WRONG-exception-handler 
  (lambda ()
    (display "Doing more stuff")(newline)
    (raise 'yet-another-exception)
    (display "Won't get here because raise will error with 'handler returned'")
    (display " when it sees I've given it back control")(newline)) )
]


;;; The handler needs to call another continuation so that it doesn't return
;;; to raise.
;;; This way will work:

(call-with-current-continuation 
  (lambda (k)
    (with-exception-handler 
      (lambda (e)
	(display "I handled an exception: ")(write e)(newline)
        (display "Passing it to previous continuation")(newline)
	(k e))
      (lambda ()
	(display "Doing more stuff")(newline)
	(raise 'yet-another-exception)
	(display "Won't get here")(newline)))) )

;;; This is kind of a pain so guard does all this plumbing for you.
