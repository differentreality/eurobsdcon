function remove_field($this) {
  // Deselect option
  var row_id = $this.parent().parent().attr('id');
  console.log("row_id: " + row_id);
  $("select#invoice_tickets option").each(function () {
    if ($(this).data('index') == row_id ){
      $(this).prop('selected', false);
    }
  });

  // Remove invoice item row
  $this.parent().parent().remove();
  payable_change();
}

function calculatePayable() {
  var payable = (parseFloat($("#invoice_vat").val()) + parseFloat($("#invoice_total_amount").val())).toFixed(2);

  $("#invoice_payable").val(payable);
}

function payable_change(total_amount) {
  if (!total_amount > 0) {
    var total_amount = parseFloat(0);

    $('#description .row').each( function() {
      price = parseFloat($(this).find('#invoice_description__price').val() || 0).toFixed(2);
      quantity = parseFloat($(this).find('#invoice_description__quantity').val()) || 0;

      total_amount = (parseFloat(total_amount) + parseFloat(price) * parseFloat(quantity)).toFixed(2);
    });
  }

  var vat_percent = parseFloat($("#invoice_vat_percent").val());
  var vat = (total_amount * vat_percent / 100).toFixed(2);

  $("#invoice_total_amount").val(total_amount);
  $("#invoice_vat").val(vat);
  calculatePayable()
}

$(function () {
  jQuery('option').mousedown(function(e) {
    e.preventDefault();
    jQuery(this).toggleClass('selected');

    jQuery(this).prop('selected', !jQuery(this).prop('selected'));
    return false;
  });

  $("[id^='tickets_collection_option']").click(function () {
    var row_id = $(this).data('index');
    var next_index = 0;
    if($(this).is(':selected')){
      $('#description .row').each( function(index, value) {
        if ( value.id > row_id ) {
          next_index = value.id;
          return false;
        }
      });

      if ( next_index == 0 ) {
        $('#description').append('<div class=row id=' + row_id + '>');
      }else{
        $('.row#' + next_index).before('<div class=row id=' + row_id + '>');
      }
      $('.row#' + row_id).append('<div class=col-md-7><input type="text" name="invoice[description][][description]" id="invoice_description__description" value="' + $(this).data('ticket-name') + '" autofocus="autofocus" class="form-control"></div> <div class=col-md-2><input type="number" name="invoice[description][][quantity]" id="invoice_description__quantity" value="' + parseFloat($(this).data('quantity')) + '" min="1" class="form-control" onchange="payable_change()"></div> <div class=col-md-2 style="padding: 0 0 0 0"> <input type="number" name="invoice[description][][price]" id="invoice_description__price" value=' +parseFloat($(this).data('price')).toFixed(1) + ' min="0" class="form-control" onchange="payable_change()"> </div><div class=col-md-1> <a onclick="remove_field($(this))" title="Remove field" href="javascript: void(0)"><i class="fa fa-times btn btn-danger"></i></a></div><input type="hidden" name="invoice[description][][ticket_id]" id="invoice_description__ticket_id" value=' + parseFloat($(this).data('ticket_id')) + '>');
    }
    else {
      $('.row#' + row_id).remove();
    }
    payable_change(0);
  });

  $("#invoice_vat_percent").change(function () {
    $("#invoice_vat").val(($("#invoice_total_amount").val() * parseFloat($("#invoice_vat_percent").val()) / 100).toFixed(2));

    calculatePayable();
  });

  $("#invoice_total_amount").change(function () {
    $("#invoice_vat").val(($("#invoice_total_amount").val() * parseFloat($("#invoice_vat_percent").val()) / 100).toFixed(2));
    calculatePayable();
  });

  $("#invoice_payable").change(function () {
    payable_change($(this).val());
  });
});
