var isWebkit = /Webkit/i.test(navigator.userAgent),
        isChrome = /Chrome/i.test(navigator.userAgent),
        isMobile = !!("ontouchstart" in window),
        isAndroid = /Android/i.test(navigator.userAgent),
        isIE = document.documentMode;

/***************
 Helpers
 ***************/

/* Randomly generate an integer between two numbers. */
function r(min, max) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
}

/* Override the default easing type with something a bit more jazzy. */
$.Velocity.defaults.easing = "easeInOutsine";

/*******************
 Dot Creation
 *******************/

/* Differentiate dot counts based on roughly-guestimated device and browser capabilities. */
var dotsCount,
        dotsHtml = "",
        $count = $("#count"),
        $dots;

if (window.location.hash) {
    dotsCount = window.location.hash.slice(1);
} else {
    dotsCount = isMobile ? (isAndroid ? 40 : 60) : (isChrome ? 200 : 175);
}

for (var i = 0; i < dotsCount; i++) {
    dotsHtml += "<div class='dot'></div>";
}

$dots = $(dotsHtml);

$count.html(dotsCount);

/*************
 Setup
 *************/

var $container = $("#animated-balls");

var screenWidth = $(window).width(),
        screenHeight = $(window).height(),
        chromeHeight = screenHeight - (document.documentElement.clientHeight || screenHeight);

var translateZMin = -725,
translateZMax = 300;

var containerAnimationMap = {
    perspective: [215, 100],
    opacity: [0.90, 0.80]
};

/* IE10+ produce odd glitching issues when you rotateZ on a parent element subjected to 3D transforms. */
if (!isIE) {
    containerAnimationMap.rotateZ = [5, 0];
}

/*****************
 Animation
 *****************/

$container
        .css("perspective-origin", screenWidth / 2 + "px " + ((screenHeight * 0.45) - chromeHeight) + "px")
        .velocity(containerAnimationMap, {duration: 800, loop: 1, delay: 3250});






/* Animate the dots. */
$dots
        .velocity({
            translateX: [
                function () {
                    return "+=" + r(-screenWidth / 2.5, screenWidth / 2.5)
                },
                function () {
                    return r(0, screenWidth)
                }
            ],
            translateY: [
                function () {
                    return "+=" + r(-screenHeight / 2.75, screenHeight / 2.75)
                },
                function () {
                    return r(0, screenHeight)
                }
            ],
            translateZ: [
                function () {
                    return "+=" + r(translateZMin, translateZMax)
                },
                function () {
                    return r(translateZMin, translateZMax)
                }
            ],
            opacity: [
                function () {
                    return Math.random()
                },
                function () {
                    return Math.random() + 0.1
                }
            ]
        }, {duration: 6000, loop: true})
        .velocity("reverse")
        .appendTo($container);