import { useState } from 'react';
import axios from 'axios';
import { useAuth } from '../context/AuthContext';

const AddFamilyMember = () => {
    const [name, setName] = useState('');
    const [gender, setGender] = useState('');
    const [yearOfBirth, setYearOfBirth] = useState('');
    const [parentId, setParentId] = useState('');
    const [spouseId, setSpouseId] = useState('');
    const { user } = useAuth();

    const handleSubmit = async (e) => {
        e.preventDefault();
        const token = localStorage.getItem('token');
        await axios.post('/api/family', { name, gender, yearOfBirth, parentId, spouseId }, {
            headers: { Authorization: `Bearer ${token}` }
        });
    };

    return (
        <form onSubmit={handleSubmit}>
            <input type="text" value={name} onChange={(e) => setName(e.target.value)} placeholder="Name" />
            <select value={gender} onChange={(e) => setGender(e.target.value)}>
                <option value="">Select Gender</option>
                <option value="Male">Male</option>
                <option value="Female">Female</option>
            </select>
            <input type="number" value={yearOfBirth} onChange={(e) => setYearOfBirth(e.target.value)} placeholder="Year of Birth" />
            <input type="text" value={parentId} onChange={(e) => setParentId(e.target.value)} placeholder="Parent ID" />
            <input type="text" value={spouseId} onChange={(e) => setSpouseId(e.target.value)} placeholder="Spouse ID" />
            <button type="submit">Add Family Member</button>
        </form>
    );
};

export default AddFamilyMember;
