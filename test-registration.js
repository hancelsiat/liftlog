
const axios = require('axios');
const FormData = require('form-data');

const form = new FormData();
form.append('username', 'testuser2');
form.append('email', 'test2@example.com');
form.append('password', 'password123');

axios.post('http://localhost:10000/api/auth/register', form, {
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
