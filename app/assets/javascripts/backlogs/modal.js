/*jslint indent: 2, regexp: false */
/*globals $, Control, Element, Class, Event, window, setTimeout */
/*globals console */
var Backlogs = (function () {
  var ModalLink, ModalUpdater;

  var modalHelper = new ModalHelper();

  ModalLink = function (element) {
    element = jQuery("#" + element);

    if (element) {
      element.click(function (e) {
        modalHelper.createModal(element.attr("href"));
        e.preventDefault();
      });
    }
  };

  ModalUpdater = function (form) {
    modalHelper.submitBackground(form, {autoReplace: true})
  };

  return {
    ModalUpdater: ModalUpder,
    ModalLink : ModalLink
  };
}());
