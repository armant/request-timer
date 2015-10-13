$(document).ready ->
  $('#timestampsTableBody>tr').click ->
    timestamp = $(this).data 'timestamp'
    window.location = "/timestamp/#{ timestamp }"