require('dotenv').config();
const express = require('express');
const axios = require('axios');

const app = express();
const PORT = 3000;

/*
    Simple in-memory token store.
    In production, replace with database.
*/
let dexcomTokens = {
    access_token: null,
    refresh_token: null,
    expires_at: null
};

/*
    Redirect user to Dexcom login
*/
app.get('/auth/dexcom', (req, res) => {
    const authURL =
        `https://sandbox-api.dexcom.com/v2/oauth2/login` +
        `?client_id=${process.env.DEXCOM_CLIENT_ID}` +
        `&redirect_uri=${process.env.DEXCOM_REDIRECT_URI}` +
        `&response_type=code` +
        `&scope=offline_access`;

    res.redirect(authURL);
});

/*
    Dexcom redirects back here with ?code=
*/
app.get('/oauth/callback', async (req, res) => {
    const code = req.query.code;

    if (!code) {
        return res.send("No authorization code received.");
    }

    try {
        const tokenResponse = await axios.post(
            'https://sandbox-api.dexcom.com/v2/oauth2/token',
            new URLSearchParams({
                grant_type: 'authorization_code',
                code: code,
                redirect_uri: process.env.DEXCOM_REDIRECT_URI,
                client_id: process.env.DEXCOM_CLIENT_ID,
                client_secret: process.env.DEXCOM_CLIENT_SECRET
            }),
            {
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
            }
        );

        const data = tokenResponse.data;

        dexcomTokens.access_token = data.access_token;
        dexcomTokens.refresh_token = data.refresh_token;
        dexcomTokens.expires_at = Date.now() + (data.expires_in * 1000);

        console.log("Tokens stored successfully.");

        res.send("OAuth successful. You can now call /dexcom/egvs");

    } catch (error) {
        console.error(error.response?.data || error.message);
        res.send("Token exchange failed.");
    }
});

/*
    Helper: Refresh token if expired
*/
async function ensureValidAccessToken() {

    if (!dexcomTokens.access_token) {
        throw new Error("User not authenticated.");
    }

    // If token is still valid, return it
    if (Date.now() < dexcomTokens.expires_at - 60000) {
        return dexcomTokens.access_token;
    }

    console.log("Access token expired. Refreshing...");

    const refreshResponse = await axios.post(
        'https://sandbox-api.dexcom.com/v2/oauth2/token',
        new URLSearchParams({
            grant_type: 'refresh_token',
            refresh_token: dexcomTokens.refresh_token,
            client_id: process.env.DEXCOM_CLIENT_ID,
            client_secret: process.env.DEXCOM_CLIENT_SECRET
        }),
        {
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
        }
    );

    const data = refreshResponse.data;

    dexcomTokens.access_token = data.access_token;
    dexcomTokens.refresh_token = data.refresh_token;
    dexcomTokens.expires_at = Date.now() + (data.expires_in * 1000);

    console.log("Token refreshed successfully.");

    return dexcomTokens.access_token;
}

/*
    Format Date function
*/
function formatDexcomDate(date) {
    const pad = (n) => n.toString().padStart(2, '0');

    return (
        date.getFullYear() + '-' +
        pad(date.getMonth() + 1) + '-' +
        pad(date.getDate()) + 'T' +
        pad(date.getHours()) + ':' +
        pad(date.getMinutes()) + ':' +
        pad(date.getSeconds())
    );
}

/*
    Fetch Glucose Data
*/
app.get('/dexcom/egvs', async (req, res) => {
    try {
        const accessToken = await ensureValidAccessToken();

        const now = new Date();
        const startDate = new Date(now.getTime() - 3 * 60 * 60 * 1000);

        const response = await axios.get(
            'https://sandbox-api.dexcom.com/v3/users/self/egvs',
            {
                headers: {
                    Authorization: `Bearer ${accessToken}`
                },
                params: {
                    startDate: formatDexcomDate(startDate),
                    endDate: formatDexcomDate(now)
                }
            }
        );

        res.json(response.data);

    } catch (error) {
        console.error(error.response?.data || error.message);
        res.status(500).send("Failed to fetch glucose data.");
    }
});

app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
});