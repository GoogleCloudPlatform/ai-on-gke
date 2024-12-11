import React from 'react';
import { Link } from 'react-router-dom';

const NavBar = ({ user, login, logOut }) => {
  return (
    <nav className="navbar">
      <ul className="nav-list">
        <li className="nav-item">
          <Link to="/" className="nav-link">Home</Link>
        </li>
        <li className="nav-item">
          <Link to="/game" className="nav-link">Game</Link>
        </li>
        {user ? (
          <li className="user-section">
            <div className="nav-user-info">
              <img src={user.picture} alt={user.name} className='nav-profile-avatar' />
              <span>{user.name}</span>
            </div>
            <button onClick={logOut} className="logout-button">Logout</button>
          </li>
        ) : (
          <li className="user-section">
            <button onClick={login} className="login-button">Login with Google</button>
          </li>
        )}
      </ul>
    </nav>
  );
};

export default NavBar;
