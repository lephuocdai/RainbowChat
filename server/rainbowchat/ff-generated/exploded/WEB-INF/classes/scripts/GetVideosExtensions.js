// exports.setupReuvenTest = function() {
//     var ff = require('ffef/FatFractal');  // import the FatFractal library
//     ff.deleteAllForQuery("/FFUser/(reuvenTest eq true)");
//     ff.deleteAllForQuery("/RCVideo");

//     var users = [];
//     // Create 6 users
//     var userIx;
//     for (userIx = 1; userIx <= 6; userIx++) {
//         var guid = 'ReuvenTestUser_' + userIx;
//         var password = guid;
//         var user = JSON.parse(JSON.stringify({clazz:'FFUser',reuvenTest:true, guid: guid, userName:guid}));
//         user = ff.registerUser(user, password, true, false);
//         users.push(user);
//     }

//     var rcvideos = [];
//     // Create 5 rcvideos - rcvideo 1 will have 2 users, rcvideo 2 - 3 users, ..., rcvideo 5 - 6 users
//     var rcvideoIx;
//     for (rcvideoIx = 1; rcvideoIx <= 5; rcvideoIx++) {
//         var rcvid = {clazz:'RCVideo', userNameList:[]};
//         for (userIx = 0; userIx <= rcvideoIx; userIx++) {
//             rcvid.userNameList.push(users[userIx].userName);
//         }
//         rcvid = ff.createObjAtUri(rcvid, "/RCVideo");
//         rcvideos.push(rcvid);
//         rcvid.usersAsList = [];
//         for (userIx = 0; userIx <= rcvideoIx; userIx++) {
//             ff.grabBagAdd(users[userIx].ffUrl, rcvid.ffUrl, 'users');
//         }
//     }

//     ff.response().result = {users:users,rcvideos:rcvideos}
// };

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


// exports.testReuvenTest = function() {
//     var ff = require('ffef/FatFractal');  // import the FatFractal library
//     // Given a list of user names
//     var userNamesParam = ff.getExtensionRequestData().httpParameters['userNames'];
//     if (!userNamesParam)
//         throw "You must supply a userNames parameter (comma-separated list of userName values)";

//     var userNames = userNamesParam.split(',');
//     if (!userNames || ! (userNames.length))
//         throw "You must supply a userNames parameter (comma-separated list of userName values)";

//     // Retrieve those users
//     var userIx;
//     var users = [];
//     var user = null;
//     for (userIx = 0; userIx < userNames.length; userIx++) {
//         user = ff.getObjFromUri("/FFUser/(userName eq '" + userNames[userIx] + "')");
//         if (!user)
//             throw "Unable to find user with userName eq '" + userNames[userIx] + "'";
//         users.push(user);
//     }

//     // Find all rcvideos with ONLY those users
//     // Let's start by getting all rcvideos that involve the first user
//     var user1_rcvideos = ff.getArrayFromUri("/FFUser/" + users[0].guid + "/BackReferences.RCVideo.users");
//     var matchedrcvideos = [];
//     // Let's iterate through all of the rcvideos that user1 is a part of
//     var rcvideoIx;
//     for (rcvideoIx = 0; rcvideoIx < user1_rcvideos.length; rcvideoIx++) {
//         var rcvideo = user1_rcvideos[rcvideoIx];
//         // For each rcvideo that user 1 is a part of, get all of the other users who are part of the rcvideo
//         var otherUsersThisRCVideo = ff.grabBagGetAllForQuery(rcvideo.ffUrl, "users", "(guid ne '" + users[0].guid + "')");
//         // If the number of users doesn't match, move on to the next rcvideo
//         if ((otherUsersThisRCVideo.length + 1) != users.length)
//             continue;

//         // Now, let's iterate through the rest of the users in the list supplied
//         for (userIx = 1; userIx < users.length; userIx++) {
//             // For each user, let's check if they are a member of this rcvideo
//             var matchedOtherUser = false;
//             for (var k = 0; k < otherUsersThisRCVideo.length; k++) {
//                 var otherUser = otherUsersThisRCVideo[k];
//                 if (users[userIx].guid == otherUser.guid)
//                     matchedOtherUser = true;
//             }
//             if (! matchedOtherUser) // failed to match a user - not part of the set
//                 break;
//         }
//         if (userIx == users.length) // all users were matched
//             matchedrcvideos.push(rcvideo);
//     }

//     ff.response().result = matchedrcvideos;
// };

// - (void) testReuvenTest {
//     __block BOOL blockComplete = NO;
//     [ff getArrayFromExtension:@"/testReuvenTest?userNames=ReuvenTestUser_3,ReuvenTestUser_1,ReuvenTestUser_2" onComplete:^(NSError *theErr, id theObj, NSHTTPURLResponse *theResponse) {
//         STAssertNil(theErr, @"Got error from extension: %@", [theErr localizedDescription]);
//         NSArray *rcvideos = (NSArray *)theObj;
//         STAssertTrue([rcvideos count] == 1, @"Expected 1 rcvideo, got %d", [rcvideos count]);
//         NSLog(@"RCVideos: \n%@", rcvideos);
//         blockComplete = YES;
//     }];
//     while (!blockComplete) {
//         NSDate* cycle = [NSDate dateWithTimeIntervalSinceNow:0.001];
//         [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
//                                  beforeDate:cycle];
//     }
// }