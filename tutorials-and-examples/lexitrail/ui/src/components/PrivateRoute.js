import React from 'react';
import Profile from './Profile.js';


function PrivateRoute({ profileDetails, login, logOut, children }) {
    return profileDetails ? children :
        <Profile profileDetails={profileDetails} login={login} logout={logOut} />;
}

export default PrivateRoute;
