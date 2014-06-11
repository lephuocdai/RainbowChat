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

    var ios_content = {
    	"aps" : {
    		"alert" : {
    			"body" : messageString,
    			"action-loc-key" : "PLAY"
    		},
    		"badge" : 1
    	},
    	"fromUser" : fromUserGUID
    };
    ff.sendPushNotifications ([toUserGUID], {ios:ios_content}, false);
    ff.response().result = messageString;
}