import { Blob } from 'buffer';

const BASE_URL = 'http://127.0.0.1:3000/api';

async function runTests() {
  console.log('=========================================');
  console.log('     STARTING BACKEND API INTEGRATION TESTS  ');
  console.log('=========================================');

  let adminToken = '';
  let sellerToken = '';
  let testItemId = null;

  // 1. Test Admin Login
  try {
    console.log('\n[TEST 1] Admin Login...');
    const res = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'admin', password: 'admin123' })
    });
    const data = await res.json();
    if (res.status === 200 && data.token) {
      adminToken = data.token;
      console.log('✅ Admin login successful! Role:', data.user.role);
    } else {
      throw new Error(`Failed: status ${res.status}, ${JSON.stringify(data)}`);
    }
  } catch (err) {
    console.error('❌ Admin Login Test Failed:', err.message);
    process.exit(1);
  }

  // 2. Test Seller Login
  try {
    console.log('\n[TEST 2] Seller Login...');
    const res = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'seller', password: 'seller123' })
    });
    const data = await res.json();
    if (res.status === 200 && data.token) {
      sellerToken = data.token;
      console.log('✅ Seller login successful! Role:', data.user.role);
    } else {
      throw new Error(`Failed: status ${res.status}, ${JSON.stringify(data)}`);
    }
  } catch (err) {
    console.error('❌ Seller Login Test Failed:', err.message);
    process.exit(1);
  }

  // 3. Test Role Verification (/me endpoint)
  try {
    console.log('\n[TEST 3] Fetching Profile details (/me)...');
    const res = await fetch(`${BASE_URL}/auth/me`, {
      headers: { 'Authorization': `Bearer ${adminToken}` }
    });
    const data = await res.json();
    if (res.status === 200 && data.username === 'admin') {
      console.log('✅ Token authentication and profile fetch succeeded!');
    } else {
      throw new Error(`Failed: status ${res.status}`);
    }
  } catch (err) {
    console.error('❌ Profile Fetch Failed:', err.message);
    process.exit(1);
  }

  // 4. Test Seller is Forbidden from Creating Items
  try {
    console.log('\n[TEST 4] Verifying Seller cannot create items (Role-based access)...');
    const res = await fetch(`${BASE_URL}/items`, {
      method: 'POST',
      headers: { 
        'Authorization': `Bearer ${sellerToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ name: 'Sneakers', price: 89.99, quantity: 5 })
    });
    if (res.status === 403) {
      console.log('✅ Success! Seller got 403 Forbidden as expected.');
    } else {
      throw new Error(`Expected 403, got status ${res.status}`);
    }
  } catch (err) {
    console.error('❌ Seller role boundary test failed:', err.message);
    process.exit(1);
  }

  // 5. Test Admin Creating Item (No Photo)
  try {
    console.log('\n[TEST 5] Admin creating item without photo...');
    const formData = new FormData();
    formData.append('name', 'Pantalón Jeans');
    formData.append('price', '45.50');
    formData.append('quantity', '20');
    formData.append('type', 'Pantalón');

    const res = await fetch(`${BASE_URL}/items`, {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${adminToken}` },
      body: formData
    });
    const data = await res.json();
    if (res.status === 201 && data.id && data.type === 'Pantalón') {
      testItemId = data.id;
      console.log(`✅ Item created successfully! ID: ${data.id}, Name: ${data.name}, Type: ${data.type}, Photo URL: ${data.photo_url}`);
    } else {
      throw new Error(`Failed: status ${res.status}, ${JSON.stringify(data)}`);
    }
  } catch (err) {
    console.error('❌ Item creation test failed:', err.message);
    process.exit(1);
  }

  // 6. Test Admin Creating Item (With Mock Photo Upload)
  try {
    console.log('\n[TEST 6] Admin creating item with photo...');
    const formData = new FormData();
    formData.append('name', 'Camisa Elegante');
    formData.append('price', '29.99');
    formData.append('quantity', '15');
    formData.append('type', 'Camisa');
    
    // Create a mock image binary
    const mockImageContent = Buffer.from('fake-image-binary-data');
    const mockBlob = new Blob([mockImageContent], { type: 'image/png' });
    formData.append('photo', mockBlob, 'test_camisa.png');

    const res = await fetch(`${BASE_URL}/items`, {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${adminToken}` },
      body: formData
    });
    const data = await res.json();
    if (res.status === 201 && data.photo_url && data.type === 'Camisa') {
      console.log(`✅ Item with photo created! ID: ${data.id}, Type: ${data.type}, Photo URL: ${data.photo_url}`);
    } else {
      throw new Error(`Failed: status ${res.status}, ${JSON.stringify(data)}`);
    }
  } catch (err) {
    console.error('❌ Item creation with photo failed:', err.message);
    process.exit(1);
  }

  // 7. Test Admin Reading Items
  try {
    console.log('\n[TEST 7] Fetching all items (Admin/Seller access)...');
    const res = await fetch(`${BASE_URL}/items`, {
      headers: { 'Authorization': `Bearer ${sellerToken}` }
    });
    const data = await res.json();
    if (res.status === 200 && Array.isArray(data)) {
      console.log(`✅ Retrieved ${data.length} items successfully.`);
    } else {
      throw new Error(`Failed: status ${res.status}`);
    }
  } catch (err) {
    console.error('❌ Fetch items test failed:', err.message);
    process.exit(1);
  }

  // 8. Test Admin Updating Item
  try {
    console.log(`\n[TEST 8] Admin updating item ID ${testItemId}...`);
    const formData = new FormData();
    formData.append('name', 'Pantalón Jeans Premium');
    formData.append('price', '49.99');
    formData.append('quantity', '22');
    formData.append('type', 'Pantalón');

    const res = await fetch(`${BASE_URL}/items/${testItemId}`, {
      method: 'PUT',
      headers: { 'Authorization': `Bearer ${adminToken}` },
      body: formData
    });
    const data = await res.json();
    if (res.status === 200 && data.name === 'Pantalón Jeans Premium' && parseFloat(data.price) === 49.99 && data.type === 'Pantalón') {
      console.log('✅ Item updated successfully! New name:', data.name, 'New price:', data.price, 'New type:', data.type);
    } else {
      throw new Error(`Failed: status ${res.status}, ${JSON.stringify(data)}`);
    }
  } catch (err) {
    console.error('❌ Item update test failed:', err.message);
    process.exit(1);
  }

  // 9. Test Admin Deleting Item
  try {
    console.log(`\n[TEST 9] Admin deleting item ID ${testItemId}...`);
    const res = await fetch(`${BASE_URL}/items/${testItemId}`, {
      method: 'DELETE',
      headers: { 'Authorization': `Bearer ${adminToken}` }
    });
    const data = await res.json();
    if (res.status === 200 && data.message.includes('deleted')) {
      console.log('✅ Item deleted successfully!');
    } else {
      throw new Error(`Failed: status ${res.status}, ${JSON.stringify(data)}`);
    }
  } catch (err) {
    console.error('❌ Item deletion test failed:', err.message);
    process.exit(1);
  }

  // 10. Test Failed Login
  try {
    console.log('\n[TEST 10] Verifying failed login registers (Audit Log check)...');
    const res = await fetch(`${BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'invalid_user', password: 'wrongpassword' })
    });
    if (res.status === 401) {
      console.log('✅ Success! Got 401 Unauthorized for bad login as expected.');
    } else {
      throw new Error(`Expected 401, got status ${res.status}`);
    }
  } catch (err) {
    console.error('❌ Failed login boundary test failed:', err.message);
    process.exit(1);
  }

  // 11. Test Fetch Sales Statistics
  try {
    console.log('\n[TEST 11] Admin fetching sales statistics...');
    const res = await fetch(`${BASE_URL}/sales/stats`, {
      method: 'GET',
      headers: { 
        'Authorization': `Bearer ${adminToken}`,
        'Content-Type': 'application/json'
      }
    });
    const data = await res.json();
    if (res.status === 200 && data.summary && Array.isArray(data.products) && Array.isArray(data.hourly) && Array.isArray(data.daily)) {
      console.log('✅ Sales statistics fetched successfully!');
      console.log(`   Summary: Revenue=$${data.summary.totalRevenue}, Sales=${data.summary.totalSales}, Avg=$${data.summary.avgSaleValue}`);
      console.log(`   Top Product: ${data.products.length > 0 ? `${data.products[0].name} (${data.products[0].quantity} units)` : 'None'}`);
    } else {
      throw new Error(`Failed: status ${res.status}, ${JSON.stringify(data)}`);
    }
  } catch (err) {
    console.error('❌ Sales stats test failed:', err.message);
    process.exit(1);
  }

  // 12. Test Logout
  try {
    console.log('\n[TEST 12] Admin logging out...');
    const res = await fetch(`${BASE_URL}/auth/logout`, {
      method: 'POST',
      headers: { 
        'Authorization': `Bearer ${adminToken}`,
        'Content-Type': 'application/json'
      }
    });
    const data = await res.json();
    if (res.status === 200 && data.message.includes('cerrada')) {
      console.log('✅ Admin logged out from server successfully!');
    } else {
      throw new Error(`Failed: status ${res.status}, ${JSON.stringify(data)}`);
    }
  } catch (err) {
    console.error('❌ Logout test failed:', err.message);
    process.exit(1);
  }

  console.log('\n=========================================');
  console.log('     ALL API INTEGRATION TESTS PASSED 🎉 ');
  console.log('=========================================');
  process.exit(0);
}

runTests();
