(in-package :cl-neovim-tests)
(in-suite neovim-test-suite)


(defmacro capture-reported-spec (spec defform)
  `(let ((nvim::*specs*)
         (nvim::*using-host* T))
     ,defform
     (cond ((and (stringp ,spec) (string= ,spec "opts"))
              (sort (alexandria:hash-table-alist (gethash "opts" (first nvim::*specs*)))
                    #'string< :key #'car))
            (,spec (gethash ,spec (first nvim::*specs*)))
            (T (first nvim::*specs*)))))

(test callback-name-specs
   (is (string= "Test"           (capture-reported-spec "name" (nvim:defun test ()))))
   (is (string= "TestLongName"   (capture-reported-spec "name" (nvim:defun test-long-name ()))))
   (is (string= "TestStringName" (capture-reported-spec "name" (nvim:defun "TestStringName" ())))))

(test callback-sync-specs
   (is (eq :false (capture-reported-spec "sync" (nvim:defcommand test ()))))
   (is (eq T      (capture-reported-spec "sync" (nvim:defcommand/s test ()))))
   (is (eq :false (capture-reported-spec "sync" (nvim:defautocmd test ()))))
   (is (eq T      (capture-reported-spec "sync" (nvim:defautocmd/s test ()))))
   (is (eq :false (capture-reported-spec "sync" (nvim:defun test ()))))
   (is (eq T      (capture-reported-spec "sync" (nvim:defun/s test ())))))

(test callback-type-specs
   (is (string= "command"  (capture-reported-spec "type" (nvim:defcommand test ()))))
   (is (string= "command"  (capture-reported-spec "type" (nvim:defcommand/s test ()))))
   (is (string= "autocmd"  (capture-reported-spec "type" (nvim:defautocmd test ()))))
   (is (string= "autocmd"  (capture-reported-spec "type" (nvim:defautocmd/s test ()))))
   (is (string= "function" (capture-reported-spec "type" (nvim:defun test ()))))
   (is (string= "function" (capture-reported-spec "type" (nvim:defun/s test ())))))

(test callback-opts-specs
   (is (equal '(("nargs" . "*"))
              (capture-reported-spec "opts"
                (nvim:defcommand/s test () (declare (opts nargs))))))
   (is (equal  '(("nargs" . "*"))
               (capture-reported-spec "opts"
                 (nvim:defcommand test () (declare (opts nargs))))))
   (is (equal '(("bang" . "") ("nargs" . "*") ("range" . "%"))
               (capture-reported-spec "opts"
                 (nvim:defcommand test () (declare (opts range bang nargs))))))
   (is (equal '(("bang" . "") ("bar" . "") ("eval" . "eval") ("nargs" . "*") ("range" . "%") ("register" . ""))
               (capture-reported-spec "opts"
                 (nvim:defcommand test () (declare (opts range bang bar nargs (vim-eval "eval") register))))))
   (is (equal '(("bang" . "") ("bar" . "") ("complete" . "file") ("count" . "") ("eval" . "eval") ("nargs" . "?") ("register" . ""))
               (capture-reported-spec "opts"
                 (nvim:defcommand test () (declare (opts count bang bar (nargs "?") (complete "file") (vim-eval "eval") register))))))
   ;; TODO: buffer?

   (is (equal '(("pattern" . "*"))
               (capture-reported-spec "opts"
                 (nvim:defautocmd test ()))))
   (is (equal '(("pattern" . "*.lisp"))
               (capture-reported-spec "opts"
                 (nvim:defautocmd test () (declare (opts (pattern "*.lisp")))))))
   (is (equal '(("eval" . "eval") ("pattern" . "*"))
               (capture-reported-spec "opts"
                 (nvim:defautocmd test (eval-arg) (declare (opts (pattern "*") (vim-eval "eval")))))))

   (is (equal '(("eval" . "eval"))
               (capture-reported-spec "opts"
                 (nvim:defun test-long-name () (declare (opts (vim-eval "eval"))))))))


(nvim:defcommand/s "LispHostTestSameCallbackName" ()
  (declare (opts bang))
  (set-result-in-nvim "first cmd"))

(nvim:defcommand/s "LispHostTestSameCallbackName" ()
  (set-result-in-nvim "second cmd"))

(nvim:defun/s "LispHostTestSameCallbackName" ()
  (set-result-in-nvim "first fun"))

(test registering-duplicate-callbacks
  (is (equal "second cmd" (result-from-nvim/s (nvim:command "LispHostTestSameCallbackName"))))
  (signals mrpc:rpc-error (nvim:command "LispHostTestSameCallbackName!"))
  (is (equal "first fun" (result-from-nvim/s (nvim:call-function "LispHostTestSameCallbackName" #())))))


(nvim:defautocmd buf-enter (filename)
  (declare (opts (pattern "*.lisp_host_testa") (vim-eval "expand(\"<afile>\")")))
  (set-result-in-nvim filename))

(nvim:defautocmd buf-enter (filename)
  (declare (opts (pattern "*.lisp_host_tests") (vim-eval "expand(\"<afile>\")")))
  (set-result-in-nvim filename))

(test triggering-autocmd-callbacks
  (set-result-in-nvim NIL)
  (is (equal "test.lisp_host_testa"
             (result-from-nvim/a (nvim:command "e test.lisp_host_testa"))))
  (set-result-in-nvim NIL)
  (is (equal "test.lisp_host_tests"
             (result-from-nvim/s (nvim:command "e test.lisp_host_tests"))))
  (set-result-in-nvim NIL)
  (is (eq NIL (result-from-nvim/s (nvim:command "e test.lisp_host_test1"))))
  (nvim:command "enew"))


(nvim:defun/s lisp-host-fun-full-opts (&rest args &opts vim-eval)
  (declare (opts (vim-eval "line(\".\")-1")))
  (list args vim-eval))

(nvim:defun/s lisp-host-fun-altname-opts (&rest args &opts (vim-eval line-nr))
  (declare (opts (vim-eval "line(\".\")-1")))
  (list args line-nr))

(nvim:defun/s lisp-host-fun-extra-opts (&rest args)
  (declare (opts (vim-eval "line(\".\")-1")))
  args)

(nvim:defun/s lisp-host-fun-no-opts (&rest args)
  args)

(nvim:defun/s lisp-host-fun-args (a b &optional c d)
  (list a b c d))

(test function-callbacks
  (is (equal '((1 2 3) 0) (nvim:call-function "LispHostFunFullOpts" '(1 2 3))))
  (is (equal '((1 2 3) 0) (nvim:call-function "LispHostFunAltnameOpts" '(1 2 3))))
  (is (equal '(1 2 3)     (nvim:call-function "LispHostFunExtraOpts" '(1 2 3))))
  (is (equal '(1 2 3)     (nvim:call-function "LispHostFunNoOpts" '(1 2 3))))
  (signals mrpc:rpc-error     (nvim:call-function "LispHostFunArgs" #()))
  (signals mrpc:rpc-error     (nvim:call-function "LispHostFunArgs" '(1)))
  (is (equal '(1 "2" NIL NIL) (nvim:call-function "LispHostFunArgs" '(1 "2"))))
  (is (equal '(1 "2" 3 NIL)   (nvim:call-function "LispHostFunArgs" '(1 "2" 3))))
  (is (equal '(1 "2" 3 (4 5)) (nvim:call-function "LispHostFunArgs" '(1 "2" 3 (4 5))))))