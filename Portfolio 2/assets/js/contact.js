// Contact form handling: validation + Web3Forms submission using fetch
(function(){
    // Replace with your actual Web3Forms access key
    const ACCESS_KEY = 'YOUR_ACCESS_KEY_HERE';

    const form = document.querySelector('#footer form');
    if (!form) return;

    const nameEl = form.querySelector('#name');
    const emailEl = form.querySelector('#email');
    const messageEl = form.querySelector('#message');
    const submitBtn = form.querySelector('input[type="submit"]');

    function createStatusEl() {
        let s = form.querySelector('.form-status');
        if (!s) {
            s = document.createElement('div');
            s.className = 'form-status';
            s.style.margin = '0 0 1.2rem 0';
            form.insertBefore(s, form.firstChild);
        }
        return s;
    }

    function clearErrors() {
        form.querySelectorAll('.field .error-msg').forEach(e => e.remove());
        const status = form.querySelector('.form-status');
        if (status) status.textContent = '';
    }

    function showFieldError(el, msg) {
        clearFieldError(el);
        const wrap = el.closest('.field') || el.parentNode;
        const span = document.createElement('span');
        span.className = 'error-msg';
        span.textContent = msg;
        span.style.color = '#d9534f';
        span.style.display = 'block';
        span.style.marginTop = '0.4rem';
        wrap.appendChild(span);
    }

    function clearFieldError(el) {
        const wrap = el.closest('.field') || el.parentNode;
        const existing = wrap.querySelector('.error-msg');
        if (existing) existing.remove();
    }

    function validate() {
        clearErrors();
        let ok = true;
        if (!nameEl.value.trim()) {
            showFieldError(nameEl, 'Please enter your name.');
            ok = false;
        }
        const email = emailEl.value.trim();
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!email) {
            showFieldError(emailEl, 'Please enter your email.');
            ok = false;
        } else if (!emailRegex.test(email)) {
            showFieldError(emailEl, 'Please enter a valid email address.');
            ok = false;
        }
        if (!messageEl.value.trim()) {
            showFieldError(messageEl, 'Please enter a message.');
            ok = false;
        }
        return ok;
    }

    function setSubmitting(submitting) {
        if (submitBtn) {
            submitBtn.disabled = submitting;
            submitBtn.value = submitting ? 'Sending...' : 'Send Message';
        }
    }

    form.addEventListener('submit', function(e){
        e.preventDefault();
        if (!validate()) return;

        setSubmitting(true);
        const statusEl = createStatusEl();
        statusEl.textContent = '';

        const data = {
            access_key: ACCESS_KEY,
            name: nameEl.value.trim(),
            email: emailEl.value.trim(),
            message: messageEl.value.trim(),
            subject: 'Portfolio Contact Form',
            to: 'emmanuelasante7997@gmail.com'
        };

        fetch('https://api.web3forms.com/submit', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        }).then(res => res.json())
        .then(json => {
            console.log('Web3Forms response:', json);
            if (json.success) {
                form.style.display = 'none';
                const th = document.createElement('div');
                th.className = 'form-success';
                th.textContent = 'Thank you! Your message has been sent.';
                th.style.padding = '2rem 0';
                th.style.fontWeight = '600';
                form.parentNode.insertBefore(th, form);
                // optionally: clear inputs
                nameEl.value = '';
                emailEl.value = '';
                messageEl.value = '';
                // mark todo done
            } else {
                throw new Error((json.message) ? json.message : 'Submission failed');
            }
        }).catch(err => {
            console.error('Submission error:', err);
            const s = createStatusEl();
            s.textContent = 'Something went wrong. Please try again.';
            s.style.color = '#d9534f';
            setSubmitting(false);
        });
    });

    // Clear field-specific error on input
    [nameEl, emailEl, messageEl].forEach(el => {
        el.addEventListener('input', () => clearFieldError(el));
    });
})();
