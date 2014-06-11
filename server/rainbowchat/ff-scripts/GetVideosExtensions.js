/*
    Here is the uri
    /rainbowchat/ff/ext/getVideos?guids=<guid1>,<guid2>
*/

exports.getVideos = function () {
    var ff = require('ffef/FatFractal');  // import the FatFractal library
    var guidsParam = ff.getExtensionRequestData().httpParameters['guids'];
    if (!guidsParam)
        throw "You must supply a guids parameter (comma-separated list of guid values)";
    var guids = guidsParam.split(',');
    if (!guids || !(guids.length))
        throw "You must supply a guids parameter (comma-separated list of guid values)";
    var userIx;
    var users = [];
    var user = null;
    for (userIx = 0; userIx < guids.length; userIx++) {
        user = ff.getObjFromUri("/FFUser/" + guids[userIx]);
        if (!user)
            throw "Unable to find user with guid eq '" + guids[userIx] + "'";
        users.push(user);
    }

    // Find all rcvideos with ONLY those users
    // Let's start by getting all rcvideos that involve the first user
    var user1_rcvideos = ff.getArrayFromUri("/FFUser/" + users[0].guid + "/BackReferences.RCVideo.users");
    var matchedrcvideos = [];
    // Let's iterate through all of the rcvideos that user1 is a part of
    var rcvideoIx;
    for (rcvideoIx = 0; rcvideoIx < user1_rcvideos.length; rcvideoIx++) {
        var rcvideo = user1_rcvideos[rcvideoIx];
        // For each rcvideo that user 1 is a part of, get all of the other users who are part of the rcvideo
        var otherUsersThisRCVideo = ff.grabBagGetAllForQuery(rcvideo.ffUrl, "users", "(guid ne '" + users[0].guid + "')");
        // If the number of users doesn't match, move on to the next rcvideo
        var matchedSecondUser = false;
        for (var i = 0; i < otherUsersThisRCVideo.length; i++) {
            var otherUser = otherUsersThisRCVideo[i];
            if (users[1].guid == otherUser.guid)
                matchedSecondUser = true;
        };
        if (matchedSecondUser)
            matchedrcvideos.push(rcvideo);
    }
    ff.response().result = matchedrcvideos;
};
