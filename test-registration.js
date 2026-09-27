
const axios = require('axios');
const FormData = require('form-data');

const form = new FormData();
form.append('username', 'final-test-user');
form.append('email', 'final-test@example.com');
form.append('password', 'password123');

axios.post('https://liftlog-7.onrender.com/api/auth/register', form, {
  headers: {
    ...form.getHeaders()
  }
})
.then(response => {
  console.log('Registration successful:', response.data);
})
.catch(error => {
  console.error('Error during registration:', error.response ? error.response.data : error.message);
});
