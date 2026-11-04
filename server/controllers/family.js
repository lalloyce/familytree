const FamilyMember = require('../models/FamilyMember');

const addFamilyMember = async (req, res) => {
    const { name, gender, yearOfBirth, parentId, spouseId } = req.body;
    const ownerId = req.user._id;
    try {
        const familyMember = new FamilyMember({ name, gender, yearOfBirth, parent: parentId, spouse: spouseId, owner: ownerId });
        await familyMember.save();
        if (parentId) {
            const parent = await FamilyMember.findById(parentId);
            parent.children.push(familyMember._id);
            await parent.save();
        }
        res.status(201).send(familyMember);
    } catch (error) {
        res.status(400).send(error);
    }
};

const getFamilyTree = async (req, res) => {
    const ownerId = req.user._id;
    try {
        const familyMembers = await FamilyMember.find({ owner: ownerId }).populate('children');
        res.send(familyMembers);
    } catch (error) {
        res.status(500).send(error);
    }
};

const deleteFamilyMember = async (req, res) => {
    const { id } = req.params;
    try {
        const familyMember = await FamilyMember.findById(id);
        if (!familyMember) {
            return res.status(404).send({ error: 'Family member not found.' });
        }
        if (familyMember.owner.toString() !== req.user._id.toString()) {
            return res.status(403).send({ error: 'Not authorized to delete this family member.' });
        }
        await familyMember.delete();
        res.send({ message: 'Family member deleted successfully.' });
    } catch (error) {
        res.status(500).send(error);
    }
};

module.exports = { addFamilyMember, getFamilyTree, deleteFamilyMember };
