/*
    Here is the uri
    /rainbowchat/ff/ext/call?guid=<guid>
*/

exports.call = function () {
	var ff = require('ffef/FatFractal');  // import the FatFractal library
	var toUserGUID = ff.getExtensionRequestData().httpParameters['guid'];
	var fromUserGUID = ff.getExtensionRequestData().ffUser;

	if (!toUserGUID)
        throw "You must supply a guid parameter";

    var messageString = "Your are called by " + fromUserGUID;
    ff.sendPushNotifications ([toUserGUID], messageString);
    ff.response().result = messageString;
}