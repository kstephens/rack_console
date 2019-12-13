(function() {
  var input  = document.getElementById("rack_console_eval_expr");

  input.addEventListener("keydown", function(event) {
    console.log("event = " + event);
    if ( event.keyCode === 13 && event.shiftKey ) {
      event.preventDefault();
      event.stopPropagation();
      var button = document.getElementById("rack_console_eval_submit");
      console.log("button = " + button);
      // button.submit();
      var form = document.getElementById("rack_console_eval_form");
      form.submit();
    }
  });
})();
