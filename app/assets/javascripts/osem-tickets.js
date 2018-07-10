function update_price($this){
    var id = $this.data('id');

    // Calculate price for row
    var value = $this.val();
    var price = $('#price_' + id).text();
    $('#total_row_' + id).text((value * price).toFixed(2));

    // Calculate total price
    var total = 0;
    $('.total_row').each(function( index ) {
        total += parseFloat($(this).text());
    });
    var discount_percent = parseFloat($('#overall_discount').attr('data-percent'));
    var discount_value = parseFloat($('#overall_discount').attr('data-value'));

    var total_discount = (total * discount_percent / 100) + discount_value;

    if (total_discount > total) {
      total_discount = total
    }

    total = total - total_discount;

    if (total < 0 ) {
      total = 0
    }

    $('#total_price').text(total.toFixed(2));
    $('#total_discount').text(total_discount.toFixed(2))
}

$( document ).ready(function() {
    $('.quantity').each(function() {
        update_price($(this));
    });

    $('.quantity').change(function() {
        update_price($(this));
    });
    $(function () {
      $('[data-toggle="tooltip"]').tooltip()
    });
});
