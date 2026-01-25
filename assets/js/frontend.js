
            function slideUpBanner(){
                var container = $( "#container" );
                //e.preventDefault();
                if (container.is( ":visible" )){
                    container.slideUp( 2000 );
                    } else {
                    container.slideDown( 2000 );
                    }
                }

             $(document).on("click","#container #inner .close span", function(e){
                slideUpBanner();
                });

             $(document).on("click","#feedback-submit", function(e){
                var error = "";
                if($("#feedbackname").val() == "")error += "Enter your name!<br>";
                if($("#feedbackemail").val() == "")error += "Enter your email!<br>";
                if($("#feedbackmessage").val() == "")error += "Enter your message!<br>";

                if(error == ""){
                    $.ajax({
                        url: "/ajax/feedback",
                        type: "post",
                        data: $("#feedback").serialize(),
                        success: function (response) {
                            if(response == "1"){
                                $("#feedbackmessage").val("");

                                $(".modal .middle div").addClass("info");
                                $(".modal .title").html("Info");
                                $(".modal .desc").html("Thank you for your feedback. We reply as we can!<br>");
                                $(".modal").fadeIn();

                                $(".feedback").toggleClass("closed");
                                }
                            }
                        });
                    }else{
                        $(".modal .middle div").addClass("alert");
                        $(".modal .title").html("Error");
                        $(".modal .desc").html(error);
                        $(".modal").fadeIn();
                        }

                return false;
            });

           $(document).on("click", ".cartTable .lines .right span", function() {
                if(!$('.cartTable .lines div').hasClass('member')){
                    //return $(this).parents(".oneLine").remove();
                    }
            });

          $(document).on("click", "#membership-button", function(e) {
              e.preventDefault();
              if($('input[name=m]').is(':checked'))$("#membership").submit();

          });

          $(document).on("click", ".priceBox .dl", function(e) {
              e.preventDefault();
              window.location.href = $(this).data('link');
          });

          $(document).on("click", ".flyEffect", function() {
            var active, animated, boxWidth;
            boxWidth = $(this).parents(".priceBox").width();
            active = $(this).parents(".priceBox").find(".lines.radioOuter.active:not(.cloned)");
            if (active.length > 0) {
              active.clone().insertAfter(active).addClass("cloned");
              animated = $(this).parents(".priceBox").find(".cloned");
              animated.css({
                "width": boxWidth,
                "top": active.offset().top - $(window).scrollTop(),
                "left": active.offset().left
              });
              setTimeout((function() {
                $(".notification").fadeIn();
                return animated.css({
                  "transform": "scale(0.2,0.2)"
                }).animate({
                  "top": $("header.visible .basket").offset().top - $(window).scrollTop() - (active.height() / 2) + ($("header.visible .basket").height() / 2),
                  "left": $("header.visible .basket").offset().left - (boxWidth / 2) + ($("header.visible .basket").width() / 2),
                  "opacity": 0
                }, {
                  duration: 800,
                  complete: function() {
                    return animated.remove();
                  }
                });
              }), 50);
              setTimeout((function() {
                return $(".notification").fadeOut();
              }), 3000);
            }
            var selectedVal = "";
            var selected = $("input[type='radio'][name='cart']:checked");
            if (selected.length > 0) {
                selectedVal = selected.val();
            }
            if(selectedVal != ""){
                $.ajax({
                    type: "POST",
                    url: "/ajax/cart",
                    data: "id=" + $('input[name=detailID]').val() + "___" + selectedVal + "&type=" + selectedVal,
                    asnyc: true,
                    success: function(data){
                        $('.cartItemcount').text(data);
                        $('.cartItemcount').show();
                        }
                    });
                }
            return false;
          });

        scr = function() {
        var szamol = 0;
        return $(".desktop .scr").each(function() {
            if(szamol == 0)w = $(this).width();
            szamol++;
            var bheight = w / 1.77;
            var bheightup = Math.ceil(bheight/10)*10;
            return $(this).css("height", bheightup);
            });
        };
        $(window).resize(scr);
        $(document).ready(scr);

/* 2020 05 03 */

    $(".addToFavourite").on("click", function() {
        var a, b;
        $(this).toggleClass("clicked");
        a = $(this).data("basic");
        b = $(this).data("clicked");
        if ($(this).hasClass("clicked")) {
          return $(this).text(b);
        } else {
          return $(this).text(a);
        }
    });

    $(".addToFavWithStar").on("click", function() {
        var a, b;
        var a = $(this).data("basic");
        var b = $(this).data("clicked");
        var id = $(this).data("video");

        if ($(this).hasClass("clicked")) {
                $.ajax({
                    type: "POST",
                    url: "/ajax/favorites",
                    data: "id=" + id + "&type=remove",
                    asnyc: false,
                    success: function(data){
                        $(".star").toggleClass("activestar");
                        $(".addToFavWithStar").toggleClass("clicked");
                        $(".addToFavWithStar").find(".text").text(a);
                        }
                    });

        } else {
                $.ajax({
                    type: "POST",
                    url: "/ajax/favorites",
                    data: "id=" + id + "&type=add",
                    asnyc: false,
                    success: function(data){
                        $(".star").addClass('activestar');
                        $(".addToFavWithStar").addClass("clicked");
                        $(".addToFavWithStar").find(".text").text(b);
                        }
                    });
        }
    });

    var leftPadding = function() {
        var w;
        w = $(".visible .right").outerWidth() - $(".visible .mailIco").outerWidth();
        return $(".bottomSection.newDesign").css({
          "paddingRight": w
        });
    };

    leftPadding();

    $(document).ready(function() {
        return leftPadding();
    });

    $(window).on("load", function() {
        return leftPadding();
    });

    $(window).resize(function() {
        return leftPadding();
    });

    $(".advancedSearch select").select2({
        minimumResultsForSearch: -1
    });

    $(".advancedSearch select[multiple]").select2({
        minimumResultsForSearch: -1,
        closeOnSelect: false
    });

    $('select[multiple]').on('select2:select', function () {
    	var uldiv = $(this).siblings('span.select2').find('ul')
    	var count = uldiv.find('li').length - 1;
     	uldiv.html("<li>"+count+" selected</li>")
    });

    $('select[multiple]').on('select2:unselect', function () {
    	var uldiv = $(this).siblings('span.select2').find('ul')
    	var count = uldiv.find('li').length - 1;
     	uldiv.html("<li>"+count+" selected</li>")
    });

    $('select[multiple]').trigger({
        type: 'select2:select'
    });

    $('.advancedSearch select').on('select2:open', function () {
    	$('.select2-results__options').scrollbar();
    });

    $(document).on("click", ".advancedBtn", function() {
        $(".advancedSearch").slideToggle();
        return $(".advancedBtn").toggleClass("topTriangle");
    });
