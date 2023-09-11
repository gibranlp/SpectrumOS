
/* =================================
 Popup Gallery
 ==================================== */
"use strict";
function ScrollStop() {
    return false;
}
function ScrollStart() {
    return true;
}

$(document).ready(function () {
    var isMobile = false;
    if (/Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent)) {
        isMobile = true;
    }
    /*==============================================================*/
    //Lightbox gallery - START CODE
    /*==============================================================*/
    $('.lightbox-gallery').magnificPopup({
        delegate: 'a',
        type: 'image',
        tLoading: 'Loading image #%curr%...',
        mainClass: 'mfp-fade',
        gallery: {
            enabled: true,
            navigateByImgClick: true,
            preload: [0, 1] // Will preload 0 - before current, and 1 after the current image
        }
    });
    
    $('.header-search-form').magnificPopup({
        mainClass: 'mfp-fade',
        closeOnBgClick: false,
        preloader: false,
        // for white backgriund
        whitebg: true,
        fixedContentPos: false,
        callbacks: {
            open: function () {
                setTimeout(function () { $('.search-input').focus(); }, 500);
                
                 $('#search-header').parent().addClass('search-popup');
                 
                if (!isMobile)
                {
                    $('body').addClass('overflow-hidden');
                    document.onmousewheel = ScrollStop;
                }
                else
                {
             
                   
                    $('body, html').on('touchmove', function(e){
                        e.preventDefault();
                    });
                }
                    
            },
            close: function () {
                if (!isMobile){
                    $('body').removeClass('overflow-hidden');
                    $('#search-header input[type=text]').each(function (index) {
                        if (index == 0) {
                            $(this).val('');
                            $("#search-header").find("input:eq(" + index + ")").css({ "border": "none", "border-bottom": "2px solid #000" });
                        }
                    });
                    document.onmousewheel = ScrollStart;
                }
                else
                {
                     $('body, html').unbind('touchmove');
                }
            }
        }
    });
    /*==============================================================*/
    //Lightbox gallery - END CODE
    /*==============================================================*/

    /*==============================================================*/
    //Ajax MagnificPopup For Onepage Portfolio - START CODE
    /*==============================================================*/
    $('.simple-ajax-popup-align-top').magnificPopup({
        type: 'ajax',
        alignTop: true,
        overflowY: 'scroll', // as we know that popup content is tall we set scroll overflow by default to avoid jump
        callbacks: {
            open: function () {
                $('.navbar .collapse').removeClass('in');
                $('.navbar a.dropdown-toggle').addClass('collapsed');
            }
        }
    });
    /*==============================================================*/
    //Ajax MagnificPopup For Onepage Portfolio - END CODE
    /*==============================================================*/

    /*==============================================================*/
    //Video MagnificPopup - START CODE
    /*==============================================================*/
    $('.popup-youtube, .popup-vimeo, .popup-gmaps').magnificPopup({
        disableOn: 700,
        type: 'iframe',
        mainClass: 'mfp-fade',
        removalDelay: 160,
        preloader: false,
        fixedContentPos: false,
        callbacks: {
            open: function () {
                if (!isMobile)
                    $('body').addClass('overflow-hidden');
            },
            close: function () {
                if (!isMobile)
                    $('body').removeClass('overflow-hidden');
            }
            // e.t.c.
        }
    });
    /*==============================================================*/
    //Video MagnificPopup - END CODE
    /*==============================================================*/

    /*==============================================================*/
    // magnificPopup - START CODE
    /*==============================================================*/
    $('.popup-youtube-landing').magnificPopup({
        disableOn: 700,
        type: 'iframe',
        mainClass: 'mfp-fade',
        removalDelay: 160,
        preloader: false,
        // for black backgriund
        blackbg: true,
        fixedContentPos: false,
        callbacks: {
            open: function () {
                if (!isMobile)
                    $('body').addClass('overflow-hidden');
            },
            close: function () {
                if (!isMobile)
                    $('body').removeClass('overflow-hidden');
            }
            // e.t.c.
        }
    });
    /*==============================================================*/
    // magnificPopup - END CODE
    /*==============================================================*/

    /*==============================================================*/
    //Single image lightbox - zoom animation - START CODE
    /*==============================================================*/
    $('.image-popup-no-margins').magnificPopup({
        type: 'image',
        closeOnContentClick: true,
        fixedContentPos: true,
        mainClass: 'mfp-no-margins mfp-with-zoom', // class to remove default margin from left and right side
        image: {
            verticalFit: true,
        },
        zoom: {
            enabled: true,
            duration: 300 // don't foget to change the duration also in CSS
        }
    });
    /*==============================================================*/
    //Single image lightbox - zoom animation - END CODE
    /*==============================================================*/

    /*==============================================================*/
    //Single image -  fits horizontally and vertically - START CODE
    /*==============================================================*/
    $('.image-popup-vertical-fit').magnificPopup({
        type: 'image',
        closeOnContentClick: true,
        mainClass: 'mfp-img-mobile',
        image: {
            verticalFit: true
        }

    });
    /*==============================================================*/
    //Single image -  fits horizontally and vertically - END CODE
    /*==============================================================*/

    /*==============================================================*/
    //Zoom gallery - START CODE
    /*==============================================================*/
    $('.zoom-gallery').magnificPopup({
        delegate: 'a',
        type: 'image',
        mainClass: 'mfp-with-zoom mfp-img-mobile',
        image: {
            verticalFit: true
        },
        gallery: {
            enabled: true
        },
        zoom: {
            enabled: true,
            duration: 300, // don't foget to change the duration also in CSS
            opener: function (element) {
                return element.find('img');
            }
        }

    });
    /*==============================================================*/
    //Zoom gallery - END CODE
    /*==============================================================*/

    /*==============================================================*/
    //Popup with form - START CODE
    /*==============================================================*/
    $('.popup-with-form').magnificPopup({
        type: 'inline',
        preloader: false,
        closeBtnInside: true,
        focus: '#name',
        // When elemened is focused, some mobile browsers in some cases zoom in
        // It looks not nice, so we disable it:
        callbacks: {
            beforeOpen: function () {
                if ($(window).width() < 700) {
                    this.st.focus = false;
                } else {
                    this.st.focus = '#name';
                }
            }
        }
    });
    /*==============================================================*/
    //Popup with form - END CODE
    /*==============================================================*/

    /*==============================================================*/
    //Modal popup - START CODE
    /*==============================================================*/
    $('.modal-popup').magnificPopup({
        type: 'inline',
        preloader: false,
        // modal: true,
        blackbg: true
    });
    $(document).on('click', '.popup-modal-dismiss', function (e) {
        e.preventDefault();
        $.magnificPopup.close();
    });
    /*==============================================================*/
    //Modal popup - END CODE
    /*==============================================================*/

    /*==============================================================*/
    //Modal popup - zoom animation - START CODE
    /*==============================================================*/
    $('.popup-with-zoom-anim').magnificPopup({
        type: 'inline',
        fixedContentPos: false,
        fixedBgPos: true,
        overflowY: 'auto',
        closeBtnInside: true,
        preloader: false,
        midClick: true,
        removalDelay: 300,
        blackbg: true,
        mainClass: 'my-mfp-zoom-in'
    });

    $('.popup-with-move-anim').magnificPopup({
        type: 'inline',
        fixedContentPos: false,
        fixedBgPos: true,
        overflowY: 'auto',
        closeBtnInside: true,
        preloader: false,
        midClick: true,
        removalDelay: 300,
        blackbg: true,
        mainClass: 'my-mfp-slide-bottom'
    });
    /*==============================================================*/
    //Modal popup - zoom animation - END CODE
    /*==============================================================*/

});