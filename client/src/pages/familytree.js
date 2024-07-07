import { useEffect, useState } from 'react';
import axios from 'axios';
import { useAuth } from '../context/AuthContext';

const FamilyTree = () => {
    const [familyMembers, setFamilyMembers] = useState([]);
    const { user } = useAuth();

    useEffect(() => {
        const fetchFamilyTree = async () => {
            const token = localStorage.getItem('token');
            const response = await axios.get('/api/family', {
                headers: { Authorization: `Bearer ${token}` }
            });
            setFamilyMembers(response.data);
        };

        fetchFamilyTree();
    }, [user]);

    return (
        <div>
            <h1>Family Tree</h1>
            <ul>
                {familyMembers.map(member => (
                    <li key={member._id}>
                        {member.name} ({member.gender}) - Born: {member.yearOfBirth}
                    </li>
                ))}
            </ul>
        </div>
    );
};

export default FamilyTree;
