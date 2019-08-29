// UIX Button Process
var btnpProcess = {
	// Start animation
	start: function(el) {
		$(el).addClass('btn-process')
		     .attr('disabled', true);
		return this;
	},
	// Error animation
	error: function(el) {
		$(el).removeClass('btn-process')
		     .addClass('btn-process-stop');
		this.clear(el);
		return this;
	},
	// Success animation
	success: function(el) {
		$(el).removeClass('btn-process')
		     .addClass('btn-process-end');
		this.clear(el);
		return this;
	},
	// Clear css class
	clear: function(el) {
		var clear = setTimeout(function() {
			$(el).removeClass('btn-process-end')
			     .removeClass('btn-process-stop')
			     .attr('disabled', false);
			clearTimeout(clear);
		}, 1000);
		return this;
	}
};

// Send Ajax Form
function sendForm(el, url, id, _btn) {
	var btn = $(el).find(_btn);

	btnpProcess.start(btn);
    $.post(url, $(el).serialize(), function(Responce) {
    	$(id).html(Responce.html);

    	if(!Responce.status) {
    		btnpProcess.error(btn);
    	}

        if(Responce.status) {
        	btnpProcess.success(btn);
        }

    	// Check Theme Input
		controllInputTheme();
    }, 'json');
}

