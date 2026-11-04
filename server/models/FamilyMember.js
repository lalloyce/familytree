const mongoose = require('mongoose');

const FamilyMemberSchema = new mongoose.Schema({
    name: { type: String, required: true },
    gender: { type: String, enum: ['Male', 'Female'], required: true },
    yearOfBirth: { type: Number },
    parent: { type: mongoose.Schema.Types.ObjectId, ref: 'FamilyMember' },
    spouse: { type: mongoose.Schema.Types.ObjectId, ref: 'FamilyMember' },
    children: [{ type: mongoose.Schema.Types.ObjectId, ref: 'FamilyMember' }],
    owner: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true }
});

module.exports = mongoose.model('FamilyMember', FamilyMemberSchema);
