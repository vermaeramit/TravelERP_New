/* ===== TravelERP App JS ===== */

$(function () {

    // Initialize DataTables
    if ($.fn.DataTable) {
        $('table.dt-table').each(function () {
            if (!$.fn.DataTable.isDataTable(this)) {
                $(this).DataTable({
                    responsive: true,
                    pageLength: 25,
                    language: {
                        search: '<i class="bi bi-search"></i>',
                        searchPlaceholder: 'Search...',
                        emptyTable: 'No records found',
                        zeroRecords: 'No matching records'
                    },
                    dom: '<"row"<"col-sm-12 col-md-6"l><"col-sm-12 col-md-6"f>>' +
                         '<"row"<"col-sm-12"tr>>' +
                         '<"row"<"col-sm-12 col-md-5"i><"col-sm-12 col-md-7"p>>'
                });
            }
        });
    }

    // Initialize Select2
    if ($.fn.select2) {
        $('select.select2').select2({
            theme: 'bootstrap-5',
            width: '100%'
        });
    }

    // Initialize Flatpickr date pickers
    if (typeof flatpickr !== 'undefined') {
        $('input.datepicker').flatpickr({ dateFormat: 'Y-m-d', allowInput: true });
        $('input.datetimepicker').flatpickr({ enableTime: true, dateFormat: 'Y-m-d H:i', allowInput: true });
    }

    // Auto-dismiss alerts
    setTimeout(() => { $('.alert.alert-success, .alert.alert-info').fadeOut('slow'); }, 4000);

    // AJAX CSRF token setup
    $.ajaxSetup({
        headers: { 'RequestVerificationToken': $('input[name="__RequestVerificationToken"]').val() }
    });

    // Confirm delete
    $(document).on('click', '.btn-confirm-delete', function (e) {
        if (!confirm('Are you sure you want to delete this record? This action cannot be undone.')) {
            e.preventDefault();
        }
    });

    // Currency formatting helper
    window.formatCurrency = function (amount, symbol) {
        symbol = symbol || '';
        return symbol + parseFloat(amount).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    };

    // Slug generator from text input
    $('input[data-slug-source]').on('input', function () {
        const target = $($(this).data('slug-source'));
        if (target.length && target.val() === '') {
            target.val($(this).val().toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, ''));
        }
    });
});
