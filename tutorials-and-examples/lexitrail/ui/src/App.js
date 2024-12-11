import React from 'react';
import { BrowserRouter as Router, Route, Routes, Navigate } from "react-router-dom";
import {Game} from './components/Game';
import Profile from './components/Profile.js';
import PrivateRoute from './components/PrivateRoute.js';
import NavBar from './components/NavBar.js';
import { useAuth } from './hooks/useAuth';
import Wordsets from './components/Wordsets';
import './styles/Global.css';
import './styles/App.css';
import './styles/NavBar.css';

const App = () => {
  const { user, login, logOut } = useAuth();

  return (
    <Router>
      <NavBar user={user} login={login} logOut={logOut} />
      <Routes>
        <Route path="/" element={<Profile profileDetails={user} login={login} logOut={logOut} />} />
        <Route path="/wordsets" element={
          <PrivateRoute profileDetails={user} login={login} logOut={logOut}>
            <Wordsets />
          </PrivateRoute>
        } />
        <Route path="/game/:wordsetId/:mode?" element={
          <PrivateRoute profileDetails={user} login={login} logOut={logOut}>
            <Game />
          </PrivateRoute>
        } />
        <Route path="/game" element={<Navigate to="/wordsets" />} />
      </Routes>
    </Router>
  );
};

export default App;
