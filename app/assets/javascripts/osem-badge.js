$(function () {

  $("#registration_badge_text").bind('keyup', function() {
      var badge_text = $(this).val();
      $('#badge-preview #badge-custom-text').text(badge_text);
  } );

});
