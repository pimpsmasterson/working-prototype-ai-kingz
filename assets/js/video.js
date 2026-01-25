$(function() {

    $('.qualitySelector').on('click', 'li', function(event) {
        event.preventDefault();
        loadVideo($(this).data('link'), true);
        });


// Initialize JWPlayer
    var $video = $('.video-container');

    function loadVideo(url, continuePlayback) {
        var videoid = $( "[name='detailID']" ).val();
        var jw = jwplayer("jw-container");
        var videopos = 0;

        if (continuePlayback) {
            var position = jw.getPosition();
        } else {
            position = 0;
        }

        jw.setup({
            file: url,
            image: $video.attr('data-video-poster'),
            width: '100%',
            aspectratio: $video.attr('data-video-aspect').replace('_', ':'),
            primary: 'flash',
            wmode: 'direct',
            startparam: "start",
    	   type: 'video/mp4',
                events:{
                    onPlay: function(event) {
                        //alert("play");
                        $.ajax({ url: '/data/playstat',
                                 data: 'a=play&m='+videoid,
                                 type: 'GET'
                        });
                    },
                    onPause: function(event) {
                        //alert("pause");
                        $.ajax({ url: '/data/playstat',
                                 data: 'a=pause&m='+videoid,
                                 type: 'GET'
                        });
                    },
                    onTime: function(event) {
                        if (Math.round(event.position) != 0 && Math.round(event.position) % 5 == 0) {
                            if(videopos != Math.round(event.position)){
                                //alert("we're after 5 seconds of video!" + event.position + " " + event.duration + " " + videopos);
                                $.ajax({ url: '/data/playstat',
                                         data: 'a=time&m='+videoid,
                                         type: 'GET'
                                });
                                videopos = Math.round(event.position);
                                }
                        }
                    }
                }
        });

        if (continuePlayback) {
            jwplayer().play();
        }
    }

    if ($video.length) {
        loadVideo($video.attr('data-video-url'));
        }

});




