/*
 * ATTENTION: The "eval" devtool has been used (maybe by default in mode: "development").
 * This devtool is neither made for production nor for readable output files.
 * It uses "eval()" calls to create a separate source file in the browser devtools.
 * If you are trying to read the output file, select a different devtool (https://webpack.js.org/configuration/devtool/)
 * or disable the default devtool with "devtool: false".
 * If you are looking for production-ready output files, see mode: "production" (https://webpack.js.org/configuration/mode/).
 */
/******/ (() => { // webpackBootstrap
/******/ 	var __webpack_modules__ = ({

/***/ "./src/style.scss":
/*!************************!*\
  !*** ./src/style.scss ***!
  \************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
eval("__webpack_require__.r(__webpack_exports__);\n// extracted by mini-css-extract-plugin\n\n\n//# sourceURL=webpack://documento/./src/style.scss?");

/***/ }),

/***/ "./src/helpers/InitThemeFromUrlParams.js":
/*!***********************************************!*\
  !*** ./src/helpers/InitThemeFromUrlParams.js ***!
  \***********************************************/
/***/ (() => {

eval("/**\r\n * @return void\r\n*/\r\nconst initDisplay = function(){\r\n    let url = new URL(location)\r\n    let display = url.searchParams.get('display')\r\n\r\n    if([\r\n        'slides',\r\n        'one-page',\r\n        'minimal'\r\n    ].includes(display)){\r\n        document.querySelector('#app').setAttribute('data-display' ,display)\r\n    }\r\n}\r\n\r\n/**\r\n * @return void\r\n*/\r\nconst initLayout = function(){\r\n    let url = new URL(location)\r\n    let layout = url.searchParams.get('layout')\r\n\r\n    if(['fwidth','boxed'].includes(layout)){\r\n        document.querySelector('#app').setAttribute('data-layout' ,layout)\r\n    }\r\n}\r\n\r\n/**\r\n * @return void\r\n*/\r\nconst initMode = function(){\r\n    let url = new URL(location)\r\n    let mode = url.searchParams.get('mode')\r\n\r\n    if(mode == 'dark'){\r\n        document.body.classList.add(mode)\r\n    }else if(mode == 'light'){\r\n        document.body.classList.add('dark')\r\n    }\r\n}\r\n\r\n/**\r\n * @return void\r\n*/\r\nconst initThemeFromUrlParams = function(){\r\n    initLayout()\r\n    initDisplay()\r\n    initMode()\r\n}()\n\n//# sourceURL=webpack://documento/./src/helpers/InitThemeFromUrlParams.js?");

/***/ }),

/***/ "./src/helpers/handleAccordion.js":
/*!****************************************!*\
  !*** ./src/helpers/handleAccordion.js ***!
  \****************************************/
/***/ (() => {

eval("/**\r\n * @return void\r\n */\r\nconst handleAccordion = function(){\r\n    document.querySelectorAll('.accordion-item')?.forEach(item => {\r\n        item.addEventListener('click' ,function(){\r\n            // hide all in parent\r\n            this.parentNode\r\n            ?.querySelectorAll('.accordion-item')\r\n            ?.forEach(accordion => accordion.classList.remove('current'))\r\n\r\n            // show current\r\n            this.classList.add('current')\r\n        })\r\n    })\r\n}()\n\n//# sourceURL=webpack://documento/./src/helpers/handleAccordion.js?");

/***/ }),

/***/ "./src/helpers/handleCodesDirection.js":
/*!*********************************************!*\
  !*** ./src/helpers/handleCodesDirection.js ***!
  \*********************************************/
/***/ (() => {

eval("const handleCodesDirection = function(){\r\n    document.querySelectorAll('code,pre')?.forEach(\r\n        item => item.setAttribute('dir' ,'ltr')\r\n    )\r\n}()\n\n//# sourceURL=webpack://documento/./src/helpers/handleCodesDirection.js?");

/***/ }),

/***/ "./src/helpers/handleLazyLoadImages.js":
/*!*********************************************!*\
  !*** ./src/helpers/handleLazyLoadImages.js ***!
  \*********************************************/
/***/ (() => {

eval("document.addEventListener(\"DOMContentLoaded\", function() {\r\n    var lazyloadImages;    \r\n    if (\"IntersectionObserver\" in window) {  \r\n      lazyloadImages = document.querySelectorAll(\".lazy\");\r\n      var imageObserver = new IntersectionObserver(function(entries) {\r\n        entries.forEach(function(entry) {\r\n          if (entry.isIntersecting) {\r\n            var image = entry.target;\r\n            image.src = image.dataset?.src;\r\n            image.classList.remove(\"lazy\");\r\n            imageObserver.unobserve(image);\r\n          }\r\n        }) \r\n      }) \r\n      \r\n      lazyloadImages?.forEach(img => imageObserver.observe(img))\r\n    }\r\n})\n\n//# sourceURL=webpack://documento/./src/helpers/handleLazyLoadImages.js?");

/***/ }),

/***/ "./src/helpers/handleModeSwitcher.js":
/*!*******************************************!*\
  !*** ./src/helpers/handleModeSwitcher.js ***!
  \*******************************************/
/***/ (() => {

eval("/**\r\n * @return void\r\n*/\r\nconst setDarkMode = function(){\r\n    document.body.classList.add('dark')\r\n    localStorage.setItem('theme','dark')\r\n}\r\n\r\n/**\r\n * @return void\r\n*/\r\nconst setLightMode = function(){\r\n    document.body.classList.add('dark')\r\n    localStorage.removeItem('theme')\r\n}\r\n\r\n/**\r\n * @return void\r\n*/\r\nconst handleModeSwitcher = function(){\r\n    let switchers = document.querySelectorAll('.mode-switcher')\r\n    switchers?.forEach(switcher => {\r\n        switcher.addEventListener('click' ,() => {\r\n            document.body.classList.contains('dark')\r\n            ? setLightMode()\r\n            : setDarkMode()\r\n        })\r\n    })\r\n}()\r\n\r\n/**\r\n * @return void\r\n*/\r\nconst setDefaultMode = function(){\r\n    !! localStorage.getItem('theme')\r\n    ? setDarkMode()\r\n    : setLightMode()\r\n}()\n\n//# sourceURL=webpack://documento/./src/helpers/handleModeSwitcher.js?");

/***/ }),

/***/ "./src/helpers/handleNestedUl.js":
/*!***************************************!*\
  !*** ./src/helpers/handleNestedUl.js ***!
  \***************************************/
/***/ (() => {

eval("/**\r\n * adds functionality for nested ul\r\n * described within sidebar\r\n * @return void\r\n */\r\nconst handleNestedUl = function() {\r\n    let items = document.querySelectorAll('.has-nested')\r\n\r\n    items?.forEach(item => {\r\n        item.addEventListener('click' ,() => item.parentNode?.classList.add('active');{\r\n            item.parentNode?.classList.toggle('active')\r\n        })\r\n    })\r\n}()\n\n//# sourceURL=webpack://documento/./src/helpers/handleNestedUl.js?");

/***/ }),

/***/ "./src/helpers/handlePopupModals.js":
/*!******************************************!*\
  !*** ./src/helpers/handlePopupModals.js ***!
  \******************************************/
/***/ (() => {

eval("/**\r\n * @return  \r\n*/\r\nconst toggleActiveClassOnClick = function(clickable){\r\n    document.querySelectorAll(clickable)?.forEach(button => {\r\n        button.addEventListener('click' ,function(){\r\n            let targetId = this.getAttribute('data-target-modal')\r\n\r\n            document.querySelector(targetId)?.classList.toggle('active')\r\n        })\r\n    })\r\n}\r\n\r\n/**\r\n * @return void\r\n */\r\nconst handlePopupModal = function(){\r\n    // open modal buttons\r\n    toggleActiveClassOnClick('.modal-opener')\r\n\r\n    // close modal buttons\r\n    toggleActiveClassOnClick('.modal-closer')\r\n}()\n\n//# sourceURL=webpack://documento/./src/helpers/handlePopupModals.js?");

/***/ }),

/***/ "./src/helpers/handlePreloader.js":
/*!****************************************!*\
  !*** ./src/helpers/handlePreloader.js ***!
  \****************************************/
/***/ (() => {

eval("/**\r\n * @return void\r\n */\r\nconst hidePreloaderOnPageLoad = function(){\r\n    window.addEventListener('load' ,function(){\r\n        document.querySelector('#preloader')?.classList.remove('active')\r\n    })\r\n}()\n\n//# sourceURL=webpack://documento/./src/helpers/handlePreloader.js?");

/***/ }),

/***/ "./src/helpers/handleScrollToTop.js":
/*!******************************************!*\
  !*** ./src/helpers/handleScrollToTop.js ***!
  \******************************************/
/***/ (() => {

eval("let scrollButton = document.getElementById(\"scroll-top\");\r\nlet container = document.getElementById('top');\r\n\r\n/**\r\n * @return void\r\n */\r\nconst handleScrollButtonToggle = function(){\r\n    container?.addEventListener('scroll' ,function(){\r\n        (container?.scrollTop > 20)\r\n        ? scrollButton?.classList.remove('hidden')\r\n        : scrollButton?.classList.add('hidden')\r\n    })\r\n}()\r\n\r\n/**\r\n * @return void\r\n */\r\nconst scrollToTopWhenClick = function(){\r\n    scrollButton?.addEventListener('click' ,function(){\r\n        container.scrollTop = 0\r\n    })\r\n}()\n\n//# sourceURL=webpack://documento/./src/helpers/handleScrollToTop.js?");

/***/ }),

/***/ "./src/helpers/handleSectionsObserve.js":
/*!**********************************************!*\
  !*** ./src/helpers/handleSectionsObserve.js ***!
  \**********************************************/
/***/ (() => {

eval("/**\r\n * handle active anchor\r\n * @return void \r\n*/\r\nconst handleAnchor = function(targetId){\r\n    let anchors = document.querySelectorAll('.sidebar a')\r\n    let nestedUl = document.querySelectorAll('.sidebar ul.nested')\r\n    let target = document.querySelector(\"a[href='#\"+targetId+\"']\")\r\n    \r\n    // revert anchors to default\r\n    anchors?.forEach(anchor => anchor.classList.remove('current'))\r\n\r\n    // close all active nested uls\r\n    nestedUl?.forEach(ul => ul.parentNode?.classList.remove('active'))\r\n\r\n    // add current to target element\r\n    target?.classList.add('current')\r\n\r\n    // open the item's nested ul if it's contained in one\r\n    target?.closest('ul')?.classList.contains('nested') \r\n    ? target.closest('ul')?.parentNode?.classList.add('active')\r\n    : null;\r\n}\r\n\r\n/**\r\n * \r\n*/\r\nconst observerCallback = (entries) => {\r\n  entries.forEach(entry => {\r\n    if (entry.isIntersecting) {\r\n      handleAnchor(entry.target.getAttribute('id'))\r\n\r\n      // render contents for section\r\n      renderTableOfContents('#' + entry.target.getAttribute('id'))\r\n    }\r\n  })\r\n}\r\n/**\r\n * create an instance of observer for sections\r\n * @return void\r\n */\r\nconst sectionsObserver = new IntersectionObserver(entries => observerCallback(entries) ,{\r\n  threshold: 0.3,\r\n  root:null\r\n})\r\n\r\nconst longSectionsObserver = new IntersectionObserver(entries => observerCallback(entries) ,{\r\n  threshold: 0.1,\r\n  root:null\r\n})\r\n\r\n/**\r\n * observe sections\r\n * @return void\r\n */\r\nconst handleSectionsObserve = function(){\r\n  document.querySelectorAll(\"section:not(.long)\")?.forEach(section => { \r\n    sectionsObserver.observe(section)\r\n  })\r\n  document.querySelectorAll(\"section.long\")?.forEach(section => { \r\n    longSectionsObserver.observe(section)\r\n  })\r\n}()\r\n\r\n/**\r\n * @return void\r\n*/\r\nconst setSectionAsCurrentOnAnchorClick = function(){\r\n  document.querySelectorAll('.sidebar a:not(.has-nested)')?.forEach(anchor => {\r\n    anchor.addEventListener('click' ,function(){\r\n      // hide all shown sections\r\n      document.querySelectorAll('section').forEach(section => section.classList.remove('current'))\r\n\r\n      // show target section\r\n      document.querySelector(this.getAttribute('href')).classList.add('current')\r\n    })\r\n  })\r\n}()\r\n\r\n/**\r\n * set section with described id in document hash as active\r\n * @rteurn void\r\n*/\r\nconst setSectionAsActive = function(){\r\n  document.querySelector('a[href=\"'+location.hash+'\"]')?.click()\r\n}()\r\n\r\n/**\r\n * render table contents based on given section\r\n * @return void\r\n*/\r\nconst renderTableOfContents = function(section){\r\n  let container = document.querySelector('#table-of-contents ul')\r\n  let sectionTitle = document.querySelector(`${section} .section-title`)\r\n  let title = document.querySelector('#table-of-contents .title')\r\n  let subTitles = document.querySelectorAll(`${section} .content-item`)\r\n\r\n  if(container){\r\n    container.innerHTML = ''\r\n    subTitles.forEach((st ,index) => {\r\n      const uid = generateSlug(st.textContent.trim()) + generateUniqueId()\r\n      container.innerHTML += `<li><a href=\"#${uid}\"><span class=\"main-text-color font-bold\">#</span> ${st.textContent} </a></li>`\r\n      st.setAttribute('id' , uid)\r\n    })\r\n    title.innerHTML = subTitles.length > 0 ? title.getAttribute('data-display-title') : ''\r\n  }\r\n}\r\n\r\n/**\r\n * @return string\r\n*/\r\nconst generateUniqueId = function(){\r\n  return (new Date()).getTime()\r\n}\r\n\r\n/**\r\n * @return string\r\n*/\r\nconst generateSlug = function(str){\r\n  return str.split(' ').filter(s => s.trim().length > 0).join('-').trim()\r\n}\n\n//# sourceURL=webpack://documento/./src/helpers/handleSectionsObserve.js?");

/***/ }),

/***/ "./src/helpers/handleSidebarToggle.js":
/*!********************************************!*\
  !*** ./src/helpers/handleSidebarToggle.js ***!
  \********************************************/
/***/ (() => {

eval("/**\r\n * @return void\r\n*/\r\nconst handleSidebarCloser = function(){\r\n    document.querySelector('#sidebar-close')?.addEventListener('click' ,function(){\r\n        document.querySelector('.sidebar')?.classList.remove('active')\r\n    })\r\n}()\r\n\r\n/**\r\n * @return void\r\n*/\r\nconst handleSidebarOpener = function(){\r\n    document.querySelector('#sidebar-open')?.addEventListener('click' ,function(){\r\n        document.querySelector('.sidebar')?.classList.add('active')\r\n    })\r\n}()\r\n\r\n/**\r\n * @return void\r\n*/\r\nconst hideSidebarOnAnyAnchorClick = function(){\r\n    document.querySelectorAll('.sidebar a:not(.has-nested)')?.forEach(a => {\r\n        a.addEventListener('click' ,function(){\r\n            document.querySelector('.sidebar')?.classList.remove('active')\r\n        })\r\n    })\r\n}()\n\n//# sourceURL=webpack://documento/./src/helpers/handleSidebarToggle.js?");

/***/ }),

/***/ "./src/helpers/handleTabs.js":
/*!***********************************!*\
  !*** ./src/helpers/handleTabs.js ***!
  \***********************************/
/***/ (() => {

eval("const handleTabs = function(){\r\n    document.querySelectorAll('.tab-navs .tab-nav')?.forEach(nav => {\r\n        nav.addEventListener('click' ,function(){\r\n            // hide all opened windows\r\n            this.parentNode?.parentNode?.querySelectorAll('.tab-window')\r\n            ?.forEach(tab => tab.classList.remove('current'))\r\n\r\n            // remove active class from active navs\r\n            this.parentNode?.parentNode?.querySelectorAll('.tab-nav')\r\n            ?.forEach(nav => nav.classList.remove('current'))\r\n\r\n            // set this as active\r\n            document.querySelector(this.dataset.target)?.classList.add('current')\r\n            this.classList.add('current')\r\n        })\r\n    })\r\n}()\n\n//# sourceURL=webpack://documento/./src/helpers/handleTabs.js?");

/***/ }),

/***/ "./src/helpers/handleThemeConfigurator.js":
/*!************************************************!*\
  !*** ./src/helpers/handleThemeConfigurator.js ***!
  \************************************************/
/***/ (() => {

eval("/**\r\n * @return void\r\n*/\r\nconst handleThemeColorConfigurator = function(){\r\n    let buttons = document.querySelectorAll('.theme-configurator button.theme-color')\r\n    \r\n    buttons?.forEach(button => {\r\n        button.addEventListener('click' ,function() {\r\n            document.querySelector('#app').setAttribute('data-theme' ,this.dataset.theme)\r\n            buttons?.forEach(button => button.classList.remove('active'))\r\n            this.classList.add('active')\r\n        })\r\n    })\r\n}()\r\n\r\n/**\r\n * @return void\r\n*/\r\nconst setActiveThemeColorOnConfiguratorButton = function(){\r\n    let active = document.querySelector('#app')?.getAttribute('data-theme')\r\n\r\n    document.querySelector('.theme-configurator button.theme-color[data-theme=\"'+active+'\"]')\r\n    ?.classList.add('active')\r\n}()\r\n\r\n/**\r\n * @return void\r\n*/\r\nconst handleThemeLayoutConfigurator = function(){\r\n    let radios = document.querySelectorAll('.theme-configurator .theme-layout')\r\n    radios?.forEach(radio => {\r\n        radio.addEventListener('change' ,function(){\r\n            document.querySelector('#app').setAttribute('data-layout' ,this.value)\r\n        })\r\n    })\r\n}()\r\n\r\n/**\r\n * @return void\r\n*/\r\nconst setActiveLayoutOnConfiguratorButton = function(){\r\n    let active = document.querySelector('#app')?.getAttribute('data-layout')\r\n    let targetInput = document.querySelector('.theme-configurator .theme-layout[value=\"'+active+'\"]')\r\n\r\n    if(active && !!targetInput)\r\n    targetInput\r\n    .checked = true\r\n}()\r\n\r\n\r\n/**\r\n * @return void\r\n*/\r\nconst handleThemeDisplayConfigurator = function(){\r\n    let radios = document.querySelectorAll('.theme-configurator .theme-display')\r\n    radios?.forEach(radio => {\r\n        radio.addEventListener('change' ,function(){\r\n            document.querySelector('#app').setAttribute('data-display' ,this.value)\r\n        })\r\n    })\r\n}()\r\n\r\n/**\r\n * @return void\r\n*/\r\nconst handleDirectionConfigurator = function(){\r\n    let radios = document.querySelectorAll('.theme-configurator .direction')\r\n    radios?.forEach(radio => {\r\n        radio.addEventListener('change' ,function(){\r\n            document.querySelector('body').setAttribute('dir' ,this.value)\r\n        })\r\n    })\r\n}()\r\n\r\n/**\r\n * @return void\r\n*/\r\nconst setActiveDisplayOnConfiguratorButton = function(){\r\n    let active = document.querySelector('#app')?.getAttribute('data-display')\r\n    let target = document.querySelector('.theme-configurator .theme-display[value=\"'+active+'\"]')\r\n    target ? target.checked = true : null\r\n}()\r\n\r\n/**\r\n * @return void\r\n*/\r\nconst setActiveDirectionOnConfiguratorButton = function(){\r\n    let active = document.querySelector('body')?.getAttribute('dir')\r\n    let target = document.querySelector('.theme-configurator .direction[value=\"'+active+'\"]')\r\n    target ? target.checked = true : null\r\n}()\r\n\r\n/**\r\n * @return void\r\n*/\r\nconst handleFormOpenButton = function(){\r\n    document.querySelector('.theme-configurator .open-button')?.addEventListener('click' ,function(){\r\n        let target = document.querySelector('.theme-configurator .form-container')\r\n        \r\n        target.classList.contains('active')\r\n        ? target.classList.remove('active')\r\n        : target.classList.add('active')\r\n    })\r\n}()\n\n//# sourceURL=webpack://documento/./src/helpers/handleThemeConfigurator.js?");

/***/ }),

/***/ "./src/index.js":
/*!**********************!*\
  !*** ./src/index.js ***!
  \**********************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

"use strict";
eval("__webpack_require__.r(__webpack_exports__);\n/* harmony import */ var _style_scss__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ./style.scss */ \"./src/style.scss\");\n/* harmony import */ var _helpers_handleNestedUl__WEBPACK_IMPORTED_MODULE_1__ = __webpack_require__(/*! ./helpers/handleNestedUl */ \"./src/helpers/handleNestedUl.js\");\n/* harmony import */ var _helpers_handleNestedUl__WEBPACK_IMPORTED_MODULE_1___default = /*#__PURE__*/__webpack_require__.n(_helpers_handleNestedUl__WEBPACK_IMPORTED_MODULE_1__);\n/* harmony import */ var _helpers_handleModeSwitcher__WEBPACK_IMPORTED_MODULE_2__ = __webpack_require__(/*! ./helpers/handleModeSwitcher */ \"./src/helpers/handleModeSwitcher.js\");\n/* harmony import */ var _helpers_handleModeSwitcher__WEBPACK_IMPORTED_MODULE_2___default = /*#__PURE__*/__webpack_require__.n(_helpers_handleModeSwitcher__WEBPACK_IMPORTED_MODULE_2__);\n/* harmony import */ var _helpers_handleSectionsObserve__WEBPACK_IMPORTED_MODULE_3__ = __webpack_require__(/*! ./helpers/handleSectionsObserve */ \"./src/helpers/handleSectionsObserve.js\");\n/* harmony import */ var _helpers_handleSectionsObserve__WEBPACK_IMPORTED_MODULE_3___default = /*#__PURE__*/__webpack_require__.n(_helpers_handleSectionsObserve__WEBPACK_IMPORTED_MODULE_3__);\n/* harmony import */ var _helpers_handleCodesDirection__WEBPACK_IMPORTED_MODULE_4__ = __webpack_require__(/*! ./helpers/handleCodesDirection */ \"./src/helpers/handleCodesDirection.js\");\n/* harmony import */ var _helpers_handleCodesDirection__WEBPACK_IMPORTED_MODULE_4___default = /*#__PURE__*/__webpack_require__.n(_helpers_handleCodesDirection__WEBPACK_IMPORTED_MODULE_4__);\n/* harmony import */ var _helpers_handleAccordion__WEBPACK_IMPORTED_MODULE_5__ = __webpack_require__(/*! ./helpers/handleAccordion */ \"./src/helpers/handleAccordion.js\");\n/* harmony import */ var _helpers_handleAccordion__WEBPACK_IMPORTED_MODULE_5___default = /*#__PURE__*/__webpack_require__.n(_helpers_handleAccordion__WEBPACK_IMPORTED_MODULE_5__);\n/* harmony import */ var _helpers_handleTabs__WEBPACK_IMPORTED_MODULE_6__ = __webpack_require__(/*! ./helpers/handleTabs */ \"./src/helpers/handleTabs.js\");\n/* harmony import */ var _helpers_handleTabs__WEBPACK_IMPORTED_MODULE_6___default = /*#__PURE__*/__webpack_require__.n(_helpers_handleTabs__WEBPACK_IMPORTED_MODULE_6__);\n/* harmony import */ var _helpers_handlePopupModals__WEBPACK_IMPORTED_MODULE_7__ = __webpack_require__(/*! ./helpers/handlePopupModals */ \"./src/helpers/handlePopupModals.js\");\n/* harmony import */ var _helpers_handlePopupModals__WEBPACK_IMPORTED_MODULE_7___default = /*#__PURE__*/__webpack_require__.n(_helpers_handlePopupModals__WEBPACK_IMPORTED_MODULE_7__);\n/* harmony import */ var _helpers_handleThemeConfigurator__WEBPACK_IMPORTED_MODULE_8__ = __webpack_require__(/*! ./helpers/handleThemeConfigurator */ \"./src/helpers/handleThemeConfigurator.js\");\n/* harmony import */ var _helpers_handleThemeConfigurator__WEBPACK_IMPORTED_MODULE_8___default = /*#__PURE__*/__webpack_require__.n(_helpers_handleThemeConfigurator__WEBPACK_IMPORTED_MODULE_8__);\n/* harmony import */ var _helpers_handleSidebarToggle__WEBPACK_IMPORTED_MODULE_9__ = __webpack_require__(/*! ./helpers/handleSidebarToggle */ \"./src/helpers/handleSidebarToggle.js\");\n/* harmony import */ var _helpers_handleSidebarToggle__WEBPACK_IMPORTED_MODULE_9___default = /*#__PURE__*/__webpack_require__.n(_helpers_handleSidebarToggle__WEBPACK_IMPORTED_MODULE_9__);\n/* harmony import */ var _helpers_handleScrollToTop__WEBPACK_IMPORTED_MODULE_10__ = __webpack_require__(/*! ./helpers/handleScrollToTop */ \"./src/helpers/handleScrollToTop.js\");\n/* harmony import */ var _helpers_handleScrollToTop__WEBPACK_IMPORTED_MODULE_10___default = /*#__PURE__*/__webpack_require__.n(_helpers_handleScrollToTop__WEBPACK_IMPORTED_MODULE_10__);\n/* harmony import */ var _helpers_handleLazyLoadImages__WEBPACK_IMPORTED_MODULE_11__ = __webpack_require__(/*! ./helpers/handleLazyLoadImages */ \"./src/helpers/handleLazyLoadImages.js\");\n/* harmony import */ var _helpers_handleLazyLoadImages__WEBPACK_IMPORTED_MODULE_11___default = /*#__PURE__*/__webpack_require__.n(_helpers_handleLazyLoadImages__WEBPACK_IMPORTED_MODULE_11__);\n/* harmony import */ var _helpers_InitThemeFromUrlParams__WEBPACK_IMPORTED_MODULE_12__ = __webpack_require__(/*! ./helpers/InitThemeFromUrlParams */ \"./src/helpers/InitThemeFromUrlParams.js\");\n/* harmony import */ var _helpers_InitThemeFromUrlParams__WEBPACK_IMPORTED_MODULE_12___default = /*#__PURE__*/__webpack_require__.n(_helpers_InitThemeFromUrlParams__WEBPACK_IMPORTED_MODULE_12__);\n/* harmony import */ var _helpers_handlePreloader__WEBPACK_IMPORTED_MODULE_13__ = __webpack_require__(/*! ./helpers/handlePreloader */ \"./src/helpers/handlePreloader.js\");\n/* harmony import */ var _helpers_handlePreloader__WEBPACK_IMPORTED_MODULE_13___default = /*#__PURE__*/__webpack_require__.n(_helpers_handlePreloader__WEBPACK_IMPORTED_MODULE_13__);\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n//# sourceURL=webpack://documento/./src/index.js?");

/***/ })

/******/ 	});
/************************************************************************/
/******/ 	// The module cache
/******/ 	var __webpack_module_cache__ = {};
/******/ 	
/******/ 	// The require function
/******/ 	function __webpack_require__(moduleId) {
/******/ 		// Check if module is in cache
/******/ 		var cachedModule = __webpack_module_cache__[moduleId];
/******/ 		if (cachedModule !== undefined) {
/******/ 			return cachedModule.exports;
/******/ 		}
/******/ 		// Create a new module (and put it into the cache)
/******/ 		var module = __webpack_module_cache__[moduleId] = {
/******/ 			// no module.id needed
/******/ 			// no module.loaded needed
/******/ 			exports: {}
/******/ 		};
/******/ 	
/******/ 		// Execute the module function
/******/ 		__webpack_modules__[moduleId](module, module.exports, __webpack_require__);
/******/ 	
/******/ 		// Return the exports of the module
/******/ 		return module.exports;
/******/ 	}
/******/ 	
/************************************************************************/
/******/ 	/* webpack/runtime/compat get default export */
/******/ 	(() => {
/******/ 		// getDefaultExport function for compatibility with non-harmony modules
/******/ 		__webpack_require__.n = (module) => {
/******/ 			var getter = module && module.__esModule ?
/******/ 				() => (module['default']) :
/******/ 				() => (module);
/******/ 			__webpack_require__.d(getter, { a: getter });
/******/ 			return getter;
/******/ 		};
/******/ 	})();
/******/ 	
/******/ 	/* webpack/runtime/define property getters */
/******/ 	(() => {
/******/ 		// define getter functions for harmony exports
/******/ 		__webpack_require__.d = (exports, definition) => {
/******/ 			for(var key in definition) {
/******/ 				if(__webpack_require__.o(definition, key) && !__webpack_require__.o(exports, key)) {
/******/ 					Object.defineProperty(exports, key, { enumerable: true, get: definition[key] });
/******/ 				}
/******/ 			}
/******/ 		};
/******/ 	})();
/******/ 	
/******/ 	/* webpack/runtime/hasOwnProperty shorthand */
/******/ 	(() => {
/******/ 		__webpack_require__.o = (obj, prop) => (Object.prototype.hasOwnProperty.call(obj, prop))
/******/ 	})();
/******/ 	
/******/ 	/* webpack/runtime/make namespace object */
/******/ 	(() => {
/******/ 		// define __esModule on exports
/******/ 		__webpack_require__.r = (exports) => {
/******/ 			if(typeof Symbol !== 'undefined' && Symbol.toStringTag) {
/******/ 				Object.defineProperty(exports, Symbol.toStringTag, { value: 'Module' });
/******/ 			}
/******/ 			Object.defineProperty(exports, '__esModule', { value: true });
/******/ 		};
/******/ 	})();
/******/ 	
/************************************************************************/
/******/ 	
/******/ 	// startup
/******/ 	// Load entry module and return exports
/******/ 	// This entry module can't be inlined because the eval devtool is used.
/******/ 	var __webpack_exports__ = __webpack_require__("./src/index.js");
/******/ 	
/******/ })()
;