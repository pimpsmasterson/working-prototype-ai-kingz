(function() {
  "use strict";
  var doc;

  doc = $(document);

  doc.ready(function() {
    var w;
    w = $(".cfBox .progress").data("percent");
    $(".cfBox .progress span").animate({
      width: w + "%"
    }, {
      duration: 2500
    });
    return $({
      countNum: 0
    }).animate({
      countNum: w
    }, {
      duration: 2500,
      step: function() {
        return $(".percentCount").text(Math.floor(this.countNum) + "%");
      },
      complete: function() {
        return $(".percentCount").text(w + "%");
      }
    });
  });

  doc.on("click", ".toggleHeader", function() {
    if ($(this).parent().hasClass("closed")) {
      $(this).parents(".toggleBoxes").find(".oneToggle").addClass("closed");
      return $(this).parent().removeClass("closed");
    } else {
      return $(this).parent().addClass("closed");
    }
  });

  doc.on("click", ".cfTabs li:not(.active)", function() {
    var i;
    i = $(this).index();
    $(".cfTabs li").removeClass("active");
    $(this).addClass("active");
    return $(".oneTab").addClass("hidden").eq(i).removeClass("hidden");
  });

}).call(this);
