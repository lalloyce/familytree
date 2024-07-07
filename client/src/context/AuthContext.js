import { createContext, useContext, useState } from 'react';
import axios from 'axios';

const AuthContext = createContext();

export const AuthProvider = ({ children }) => {
    const [user, setUser] = useState(null);

    const login = async (email, password) => {
        const response = await axios.post('/api/auth/login', { email, password });
        setUser(response.data.user);
        localStorage.setItem('token', response.data.token);
    };

    const register = async (username, email, password) => {
        const response = await axios.post('/api/auth/register', { username, email, password });
        setUser(response.data.user);
        localStorage.setItem('token', response.data.token);
    };

    const logout = () => {
        setUser(null);
        localStorage.removeItem('token');
    };

    return (
        <AuthContext.Provider value={{ user, login, register, logout }}>
            {children}
        </AuthContext.Provider>
    );
};

export const useAuth = () => {
    return useContext(AuthContext);
};
