require('dotenv').config();
const mongoose = require('mongoose');
const User = require('./models/User');

mongoose.connect(process.env.MONGODB_URI).then(async () => {
  await User.deleteMany({ email: 'lftlogapp@gmail.com' });
  await User.deleteMany({ email: 'hancelsiat@gmail.com' });
  console.log('Cleaned up test users');
  process.exit(0);
}).catch(err => {
  console.error(err);
  process.exit(1);
});
