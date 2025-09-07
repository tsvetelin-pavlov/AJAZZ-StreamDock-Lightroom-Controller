/// <reference path="../utils/common.js" />
/// <reference path="../utils/action.js" />

// $local whether to localize (i18n)
// $back whether to control when to update the view yourself
// $dom get document elements - put non-dynamic references here
const $local = true, $back = false, $dom = {
    main: $('.sdpi-wrapper')
};

const $propEvent = {
    didReceiveGlobalSettings({ settings }) {
    },
    didReceiveSettings(data) {
    },
    sendToPropertyInspector(data) {
    }
};