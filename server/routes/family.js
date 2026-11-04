const express = require('express');
const {addFamilyMember, getFamilyTree, deleteFamilyMember} = require('../controllers/family');
const auth = require('../middleware/auth');
const router = express.Router();

router.post('/family', auth, addFamilyMember);
router.get('/family', auth, getFamilyTree);
router.delete('/family/:id', auth, deleteFamilyMember);

module.exports = router;
