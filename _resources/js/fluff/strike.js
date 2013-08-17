define(['jquery'], function($) {
  return $(function($) {
    return $('strike, del').wrapInner('<span />').css('color', '#944');
  });
});
