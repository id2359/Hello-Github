; Version 1
; boot.lsp
;
  
(defun mlg1 ()
  (banner)
  (format t "~A~%" (load "../microUt/mlg.Start"))
					;(setq *gc-silence* t)  
  (myloop (read_prompt)))

(defun read_prompt () 
  (terpri)
  (format t "| ?- ")
					;(gc)
  (read_code_tail))

(defun banner ()
  (dotimes (i 2) (terpri))
  (format t "Micro_Log1 pour vous servir~%")
  (dotimes (i 2) (terpri)))

(defun l ()
  (format t "Back to MicroLog1 top-level~%")
  (myloop (read_prompt)))
; clecteur.lsp
;

(defvar *lvarloc nil)
(defvar *lvarglob nil)
(set-macro-character #\% (get-macro-character #\;))

(defun rch ()
  (do ((ch (read-char) (read-char)))
      ((char/= ch #\Newline) ch)))
(defun rchnsep ()	
  (do ((ch (rch) (rch)))
      ((char/= ch #\space) ch)))

(defun special (ch) (char= ch '#\_))
(defun alphanum (ch) (or (alphanumericp ch) (special ch)))
(defun valdigit (ch) (digit-char-p ch)) 
 
(defun read_number (ch) 
  (do ((v (valdigit ch) (+ (* v 10) (valdigit (read-char)))))
      ((not (digit-char-p (peek-char))) v)))

(defun implode (lch) (intern (map 'string #'identity lch)))

(defun read_atom (ch) 
  (do ((lch (list ch) (push (read-char) lch)))
      ((not (alphanum (peek-char))) (implode (reverse lch)))))

(defun read_at (ch)
  (do ((lch (list ch) (push (read-char) lch)))
      ((char= (peek-char) #\') (read-char) (implode (reverse lch)))))

(defun read_string (ch)
  (do ((lch (list (char-int ch)) (push (char-int (read-char)) lch)))
      ((char= (peek-char) #\") (read-char) (do_l (reverse lch)))))

(defun read_var (ch n) 
  (status (read_atom ch) n))

(defun status (nom n)
  (if (= n 1)
      (unless (member nom *lvarglob) (pushnew nom *lvarloc))
    (progn (if (member nom *lvarloc) (setq *lvarloc (delete nom *lvarloc)))
	   (pushnew nom *lvarglob)))
  nom)

(defun read_simple (ch n)
  (cond
   ((or (upper-case-p ch) (special ch)) (read_var ch n))
   ((digit-char-p ch) (read_number ch))
   ((char= ch #\") (read_string (read-char)))
   ((char= ch #\') (read_at (read-char)))
   (t (read_atom ch))))

(defun read_fct (ch n)
  (let ((fct (read_simple ch n)) (c (rchnsep)))
    (if (char= c #\()
	(let ((la (read_args (rchnsep) (1+ n))))
	  (cons (list fct (length la)) la))
      (progn (unread-char c) fct))))
                
(defun read_args (ch n) 
  (let ((arg (read_term ch n)))
    (if (char= (rchnsep) #\,)
	(cons arg (read_args (rchnsep) n))
      (list arg))))
   
(defun read_list (ch n)
  (if (char= ch #\])
      ()
    (let ((te (read_term ch n)))
      (case (rchnsep)
	    (#\, (list '(\.  2) te (read_list (rchnsep) n)))
	    (#\| (prog1 (list '(\. 2) te (read_term (rchnsep) n)) (rchnsep))) 
	    (#\] (list '(\. 2) te nil))))))

(defun read_term (ch n)
  (if (char= ch #\[) (read_list (rchnsep) (1+ n)) (read_fct ch n))) 

(defun read_tail (ch)	
  (let ((tete (read_pred ch)))
    (if (char= (rchnsep) #\.)
	(list tete)
      (cons tete (read_tail (rchnsep))))))

(defun read_clause (ch) 
  (let ((tete (read_pred ch)))
    (if (char= (rchnsep) #\.)
	(list tete)
      (progn (read-char) (cons tete (read_tail (rchnsep)))))))

(defun c (l)
  (if (atom l)
      (if (member l *lvarloc)
	  (cons 'L (position l *lvarloc))
	(if (member l *lvarglob) (cons 'G (position l *lvarglob)) l))
    (if (eq (car l) '!)
	(list '! (length *lvarloc))
      (cons (c (car l)) (c (cdr l))))))
; Version 1
; lecteur.lsp
;

(defun read_code_cl () 
  (let ((*lvarloc ()) (*lvarglob ()))
    (let ((x (read_clause (rchnsep))))
      (cons (cons (length *lvarloc) (length *lvarglob)) (c x)))))
              
(defun read_code_tail ()
  (setq *lvarloc () *lvarglob ())
  (let ((x (read_tail (rchnsep))))
    (cons (cons (length *lvarloc) (length *lvarglob)) (c x))))

(defun read_pred (ch) 
  (let ((nom (read_atom ch)) (c (rchnsep)))
    (if (char= c #\()
	(cons nom (read_args (rchnsep) 1)) 
      (progn (unread-char c) (list nom)))))
; Version 1
; blocs.lsp
;

; I. Registres
;

(defconstant BottomG 1)
(defconstant BottomL 3000)
(defconstant BottomTR 8000)
(defconstant TopTR 10000)

(defvar Mem (make-array 10000 :initial-element 0))
(defvar TR) (defvar L) (defvar G)
(defvar CP) (defvar CL)
(defvar BL) (defvar BG)
(defvar PC) (defvar PCE) (defvar PCG) (defvar Duboulot)

(defmacro vset (v i x) `(setf (svref ,v ,i) ,x))
            
; II. Local Stack 
; blocs deterministes : [CL CP E G]
;
(defmacro CL (b) `(svref Mem ,b))
(defmacro CP (b) `(svref Mem (1+ ,b)))
(defmacro G (b) `(svref Mem(+ ,b 2)))
(defmacro E (b) `(+ ,b 3))

(defmacro push_cont ()
  `(progn (vset Mem L CL) (vset Mem (1+ L) CP)))
  
(defmacro push_E (n)
  `(let ((top (+ L 3 ,n)))
     (if (>= top BottomTR) (throw 'debord (print "Local Stack Overflow")))
     (dotimes (i ,n top) (vset Mem (decf top) (cons 'LIBRE BottomG)))))
 
(defmacro maj_L (nl) `(incf L (+ 3 ,nl)))

; blocs de choix : [TR BP BL] 
;
(defmacro BL (b) `(svref Mem (1- ,b)))
(defmacro BP (b) `(svref Mem (- ,b 2)))
(defmacro TR (b) `(svref Mem (- ,b 3)))
  
(defmacro push_choix ()
  `(progn (vset Mem L TR)
	  (vset Mem (incf L 2) BL)
	  (setq BL (incf L) BG G)))

(defmacro push_bpr (reste) `(vset Mem (- BL 2) ,reste))

(defmacro pop_choix ()
  `(setq L (- L 3) BL (BL BL) BG (if (zerop BL) 0 (G BL))))

; III. Global Stack 
;
(defmacro push_G (n)
  `(let ((top (+ G ,n)))
     (if (>= top BottomL) (throw 'debord (print "Global Stack Overflow")))
     (dotimes (i ,n (vset Mem (+ L 2) G))
	      (vset Mem (decf top) (cons 'LIBRE BottomG)))))

(defmacro maj_G (ng) `(incf G ,ng))

; IV. Trail
; bloc : [adr_avr] 
;
(defmacro pushtrail (x)
  `(progn 
     (if (>= TR TopTR) (throw 'debord (print "Trail Overflow")))
     (vset Mem TR ,x)
     (incf TR)))  

(defmacro poptrail (top)
  `(do () ((= TR ,top))
       (vset Mem (svref Mem (decf TR)) (cons 'LIBRE BottomG))))
; cutili.lsp
;

(defmacro nloc (c) `(caar ,c))
(defmacro nglob (c) `(cdar ,c))
(defmacro head (c) `(cadr ,c))
(defmacro tail (c) `(cddr ,c))
(defmacro pred (g) `(car ,g))
(defmacro largs (g) `(cdr ,g))

(defmacro functor (des) `(car ,des))
(defmacro arity (des) `(cadr ,des))
(defmacro des (te) `(car ,te))
(defmacro var? (v) `(and (consp ,v) (numberp (cdr ,v))))
(defmacro list? (x) `(eq (functor (des ,x)) '\.))
 
(defmacro user? (g) `(get (pred ,g) 'def))
(defmacro builtin? (g) `(get (pred ,g) 'evaluable))
(defmacro def_of (g) 
  `(get (pred ,g) 
	(if (largs ,g)
	    (nature (car (ultimate (car (largs ,g)) PCE PCG)))
	  'def)))

(defun nature (te)
  (cond 
   ((var? te) 'def)
   ((null te) 'empty)
   ((atom te) 'atom)
   ((list? te) 'list)
   (t 'fonct)))

(defun add_cl (pred c ind)
  (setf (get pred ind) (append (get pred ind) (list c))))

(set-macro-character
 #\$
 #'(lambda (stream char)
     (let* ( (*standard-input* stream) (c (read_code_cl)))
       (add_cl (pred (head c)) c 'def)
       (if (largs (head c)) 
	   (let ((b (nature (car (largs (head c))))))
	     (if (eq b 'def)
		 (mapc 
		  #' (lambda (x) (add_cl (pred (head c)) c x))
		  '(atom empty list fonct))
	       (add_cl (pred (head c)) c b)))))
     (values)))
  
(defun answer ()
  (printvar)
  (if (zerop BL)
      (setq Duboulot nil)
    (if (and (princ "More : ") (member (read) '(o y)))
	(backtrack)
      (setq Duboulot nil))))
	
(defun printvar ()
  (if (and (null *lvarloc) (null *lvarglob))
      (format t "Yes ~%")
    (let ((nl -1) (ng -1))
      (mapc 
       #' (lambda (x)
	    (format t "~A = " x)
	    (write1 (ult (cons 'L (incf nl)) (E BottomL))) (terpri))
       *lvarloc)
      (mapc
       #' (lambda (x) 
	    (format t "~A = " x)
	    (write1 (ult (cons 'G (incf ng)) BottomG)) (terpri))
       *lvarglob))))
; Version 1
; unify.lsp
;

(defmacro bindte (x sq e) 
  `(progn  
     (if (or (and (> ,x BottomL)(< ,x BL)) (< ,x BG)) (pushtrail ,x)) 
     (rplaca (svref Mem ,x) ,sq)
     (rplacd (svref Mem ,x) ,e))) 
 
(defun unify (t1 el1 eg1 t2 el2 eg2)
  (catch 'impossible  
    (do () ((null t1))
	(unif (ultimate (pop t1) el1 eg1) (ultimate (pop t2) el2 eg2)))))
; cunify.lsp
;
 
(defmacro adr (v e) `(+ (cdr ,v) ,e)) 
(defmacro value (v e) `(svref Mem (adr ,v ,e))) 
     
(defun ult (v e) 
    (let ((te (value v e))) 
      (cond 
       ((eq (car te) 'LIBRE) (cons v e)) 
       ((var? (car te)) (ult (car te) (cdr te))) 
       ( te)))) 
 
(defun val (x e) (if (var? x) (ult x e) (cons x e))) 
 
(defun ultimate (x el eg) 
  (if (var? x)  
      (if (eq (car x) 'L) (ult x el) (ult x eg)) 
    (cons x eg))) 

(defmacro bindv (x ex y ey)
  `(let ((ax (adr ,x ,ex)) (ay (adr ,y ,ey)))
     (if (< ax ay) (bindte ay ,x ,ex) (bindte ax ,y ,ey))))
 
(defun unif (t1 t2)
  (let ((x (car t1)) (ex (cdr t1)) (y (car t2)) (ey (cdr t2)))
    (cond 
     ((var? y)  
      (if (var? x)
	  (if (= (adr x ex) (adr y ey)) t (bindv y ey x ex))
	(bindte (adr y ey) x ex)))
     ((var? x) (bindte (adr x ex) y ey))
     ((and (atom x) (atom y)) (if (eql x y) t (throw 'impossible 'fail)))
     ((or (atom x) (atom y)) (throw 'impossible 'fail))
     ( (let ((dx (pop x)) (dy (pop y)))
	 (if (and (eq (functor dx) (functor dy)) (= (arity dx) (arity dy)))
	     (do () ((null x)) 
		 (unif (val (pop x) ex) (val (pop y) ey)))
	   (throw 'impossible 'fail)))))))
; Version 1
; resol.lsp
;

(defun forward ()
  (do () ((null Duboulot) (format t "no More ~%"))
      (cond
       ((null CP) (answer))
       ((load_PC)
	(cond 
	 ((user? PC)
	  (let ((d (def_of PC))) (if d (pr d) (backtrack))))
	 ((builtin? PC)
	  (if (eq (apply (car PC) (cdr PC)) 'fail)
	      (backtrack)
	    (cont_det)))
	 ((backtrack)))))))

(defun load_PC ()
  (setq PC (car CP) PCE (E CL) PCG (G CL)))
					;(if dbg (dbg PC) t)
(defun pr (paq)
  (if (cdr paq)
      (progn (push_choix) (pr_choice paq))
    (pr_det (car paq))))

(defun pr_det (c)
  (if (eq (unify (largs PC) PCE PCG 
		   (largs (head c)) (push_E (nloc c)) (push_G (nglob c))) 
          'fail)
      (backtrack)
    (progn
      (if (tail c)
	  (progn (push_cont) (setq CP (tail c) CL L) (maj_L (nloc c)))
	(cont_det))
      (maj_G (nglob c)))))

(defun cont_det ()
  (if (cdr CP)
      (setq CP (cdr CP))
    (progn
      (if (< BL CL) (setq L CL))
      (do ()
	  ( (or (cdr (CP CL)) (zerop (CL CL)))
	    (setq CP (cdr (CP CL)) CL (CL CL)))
	  (setq CL (CL CL))
	  (if (< BL CL) (setq L CL))))))

(defun pr_choice (paq)
  (let* ((resu (shallow_backtrack paq)) (c (car resu)) (r (cdr resu)))
    (cond ((null r) (pop_choix) (pr_det c))  
	  ( (push_bpr r)
	    (push_cont)                      
	    (if (tail c)
		(setq CP (tail c) CL L)
	      (if (cdr CP)
		  (setq CP (cdr CP))    
		(do ()
		    ((or (cdr (CP CL)) (zerop (CL CL)))
		     (setq CP (cdr (CP CL)) CL (CL CL)))
		    (setq CL (CL CL)))))
	    (maj_L (nloc c)) 
	    (maj_G (nglob c))))))

(defun shallow_backtrack (paq)
  (if (and (cdr paq)
	   (eq (unify (largs PC)
			PCE
			PCG
			(largs (head (car paq)))
			(push_E (nloc (car paq)))
			(push_G (nglob (car paq))))
	       'fail))
      (progn (poptrail (TR BL))
	     (shallow_backtrack (cdr paq)))
    paq))
              
(defun backtrack ()
  (if (zerop BL)  
      (setq Duboulot nil)
    (progn
      (setq L BL G BG 
	    PC (car (CP L))
	    PCE (E (CL L)) PCG (G (CL L))
	    CP (CP L) CL (CL L))
      (poptrail (TR BL))
      (pr_choice (BP L)))))
   
(defun myloop (c)
  (setq G BottomG L BottomL TR BottomTR 
	CP nil CL 0  BL 0 BG BottomG Duboulot t)
  (push_cont)
  (push_E (nloc c))
  (push_G (nglob c)) 
  (setq CP (cdr c) CL L)
  (maj_L (nloc c))
  (maj_G (nglob c)) (read-char)
  (catch 'debord (forward))
  (myloop (read_prompt)))
; Version 1
; pred.lsp
;

(defvar Ob_Micro_Log 
      '(|write| |nl| |tab| |read| |get| |get0| 
	|var| |nonvar| |atomic| |atom| |number|
	! |fail| |true| 
	|divi| |mod| |plus| |minus| |mult| |le| |lt| 
	|name| |consult| |abolish| |cputime| |statistics|))
(mapc #' (lambda (x) (setf (get x 'evaluable) t)) Ob_Micro_Log)
  
;cut/0
(defun ! (n) 
  (unless (< BL CL)
	  (do () ((< BL CL)) (setq BL (BL BL)))
	  (setq BG (if (zerop BL) BottomG (G BL)) L (+ CL 3 n))))
; statistics/0 
(defun |statistics| ()
  (format t " local stack : ~A (~A used)~%" (- BottomTR BottomL) (- L BottomL))
  (format t " global stack : ~A (~A used)~%" BottomL (- G BottomG))
  (format t " trail : ~A (~A used)~%" (- TopTR BottomTR) (- TR BottomTR)))
; cpred.lsp
;

(defmacro value1 (x) `(car (ultimate ,x PCE PCG)))
(defun uni (x y)
  (catch 'impossible
    (unif (ultimate x PCE PCG) (ultimate y PCE PCG))))
      
					;write/1 (?term)
(defun |write| (x)
  (write1 (ultimate x PCE PCG)))

(defun write1 (te)
  (let ((x (car te)) (e (cdr te)))
    (cond 
     ((null x) (format t "[]"))
     ((atom x) (format t "~A" x))
     ((var? x) (format t "X~A" (adr x e)))
     ((list? x) (format t "[")
      (writesl (val (cadr x) e) (val (caddr x) e))
      (format t "]"))
     ((writesf (functor (des x)) (largs x) e)))))

(defun writesl (te r)
  (write1 te)
  (let ((q (car r)) (e (cdr r)))
    (cond
     ((null q))
     ((var? q) (format t "|X~A" (adr q e)))
     (t (format t ",") (writesl (val (cadr q) e) (val (caddr q) e))))))

(defun writesf (fct largs e)
  (format t "~A(" fct)
  (write1 (val (car largs) e))
  (mapc #' (lambda (x) (format t ",") (write1 (val x e))) (cdr largs))
  (format t ")"))

					;nl/0
(defun |nl| () (terpri))
					;tab/1 (+int)
(defun |tab| (x)
  (dotimes (i (value1 x)) (format t " ")))
					;read/1 (?term)
(defun |read| (x) 
  (let ((te (read_terme)))
    (catch 'impossible 
      (unif (ultimate x PCE PCG) (cons (cdr te) (push1_g (car te)))))))

(defun read_terme ()
  (let ((*lvarloc nil) (*lvarglob nil))
    (let ((te (read_term (rchnsep) 2)))
      (rchnsep) (cons (length *lvarglob) (c te)))))

(defun push1_g (n)
  (if (>= (+ G n) BottomL) (throw 'debord (print "Global Stack Overflow")))
  (dotimes (i n (- G n)) (vset Mem G (cons 'LIBRE BottomG)) (incf G)))

					;get/1 (?car)
(defun |get| (x)
  (uni x (char-int (rchnsep))))
					;get0/1 (?car)
(defun |get0| (x)
  (uni x (char-int (read-char))))
					;var/1 (?term)
(defun |var| (x)
  (unless (var? (value1 x)) 'fail))
					;nonvar/1 (?term)
(defun |nonvar| (x)
  (if (var? (value1 x)) 'fail))
					;atomic/1 (?term)
(defun |atomic| (x)
  (if (listp (value1 x)) 'fail))
					;atom/1 (?term)
(defun |atom| (x)
  (unless (symbolp (value1 x)) 'fail))
					;number/1 (?term)
(defun |number| (x)
  (unless (numberp (value1 x)) 'fail))
					;fail/0
(defun |fail| () 'fail)
					;true/0
(defun |true| ())
					;divi/3 (+int,+int,?int)
(defun |divi| (x y z)
  (uni z (floor (value1 x) (value1 y))))
					;mod/3 (+int,+int,?int)
(defun |mod| (x y z)
  (uni z (rem (value1 x) (value1 y))))
					;plus/3 (+int,+int,?int)
(defun |plus| (x y z)
  (uni z (+ (value1 x) (value1 y))))
					;minus/3 (+int,+int,?int)
(defun |minus| (x y z)
  (uni z (- (value1 x) (value1 y))))
					;mult/3 (+int,+int,?int)
(defun |mult| (x y z)
  (uni z (* (value1 x) (value1 y))))
					;le/2 (+int,+int)
(defun |le| (x y)
  (if (> (value1 x) (value1 y)) 'fail))
					;lt/2 (+int,+int)
(defun |lt| (x y)
  (if (>= (value1 x) (value1 y)) 'fail))
					;name/2 (?atom,?list)
(defun |name| (x y)
  (let ((b (value1 x)))
     (if (var? b) 
         (uni x (impl (undo_l (ultimate y PCE PCG))))
         (uni y (do_l (expl b))))))

(defun undo_l (te)
  (let ((x (car te)) (e (cdr te)))
    (if (atom x) 
	x
      (cons (undo_l (val (cadr x) e)) (undo_l (val (caddr x) e))))))
(defun do_l (x)
  (if (atom x) x (list '(\. 2) (car x) (do_l (cdr x)))))
(defun impl (l)
  (intern (map 'string #'int-char l)))
(defun expl (at)
  (map 'list #'char-int (string at)))

					;consult/1 (+atom)
(defun |consult| (f)
  (format t "~A~%" (load (value1 f))))
					; abolish/1
(defun |abolish| (p)
  (mapc  #'(lambda (x) (setf (get p x) nil))
	 '(atom empty list fonct def)))
					; cputime/1
(defun |cputime| (x)
  (uni x (float (/ (get-internal-run-time) internal-time-units-per-second))))
