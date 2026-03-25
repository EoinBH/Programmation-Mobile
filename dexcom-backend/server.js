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
        `&scope=offline_access%20egv`;

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

        res.send(`
        <html>
        <head>
        <title>Bon Sang Login</title>
        <style>
        body {
        font-family: -apple-system;
        text-align: center;
        margin-top: 100px;
        }
        button {
        font-size: 18px;
        padding: 12px 24px;
        }
        </style>
        </head>

        <body>

        <h2>Connexion réussie</h2>
        <p>Vous pouvez retourner dans l'application.</p>

        <button onclick="window.close()">Continuer</button>

        </body>
        </html>
        `);

    } catch (error) {
        console.error(error.response?.data || error.message);
        res.send("Token exchange failed.");
    }
});

/*
    Check if user is authenticated
*/
app.get('/auth/status', (req, res) => {

    if (!dexcomTokens.access_token) {
        return res.json({ authenticated: false });
    }

    res.json({
        authenticated: true,
        expires_at: dexcomTokens.expires_at
    });
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

        const hours = parseInt(req.query.hours) || 3;

        const rangeResponse = await axios.get(
            'https://sandbox-api.dexcom.com/v3/users/self/dataRange',
            {
                headers: {
                    Authorization: `Bearer ${accessToken}`
                }
            }
        );

        const dataRange = rangeResponse.data.egvs;

        const rangeStart = new Date(dataRange.start.systemTime);
        const rangeEnd = new Date(dataRange.end.systemTime);

        console.log("Sandbox range:");
        console.log("Start:", rangeStart);
        console.log("End:", rangeEnd);

        let endDate = new Date(rangeEnd);
        let startDate = new Date(endDate.getTime() - hours * 60 * 60 * 1000);

        if (startDate < rangeStart) {
            startDate = rangeStart;
        }

        console.log(`Simulating last ${hours} hours`);
        console.log("Query Start:", startDate);
        console.log("Query End:", endDate);

        const response = await axios.get(
            'https://sandbox-api.dexcom.com/v3/users/self/egvs',
            {
                headers: {
                    Authorization: `Bearer ${accessToken}`
                },
                params: {
                    startDate: formatDexcomDate(startDate),
                    endDate: formatDexcomDate(endDate)
                }
            }
        );

        console.log("Dexcom raw response:", response.data);

        res.json(response.data);

    } catch (error) {
        const err = error.response?.data;

        console.error(err || error.message);

        if (err?.error?.includes("not authorized")) {
            console.log("Token invalid. Clearing and forcing re-auth.");

            dexcomTokens = {
                access_token: null,
                refresh_token: null,
                expires_at: null
            };

            return res.status(401).send("Re-authentication required.");
        }

        res.status(500).send("Failed to fetch glucose data.");
    }
});

/*
    Reset route au cas où
*/
app.get('/auth/reset', (req, res) => {
    dexcomTokens = {
        access_token: null,
        refresh_token: null,
        expires_at: null
    };

    console.log("Tokens cleared. Forcing re-authentication.");
    res.redirect('/auth/dexcom');
});

/*
    Route pour déterminer quand les données sont disponibles (Sanbox)
*/
app.get('/dexcom/dataRange', async (req, res) => {
    try {
        const accessToken = await ensureValidAccessToken();

        const response = await axios.get(
            'https://sandbox-api.dexcom.com/v3/users/self/dataRange',
            {
                headers: {
                    Authorization: `Bearer ${accessToken}`
                }
            }
        );

        console.log("Data range:", response.data);
        res.json(response.data);

    } catch (error) {
        console.error(error.response?.data || error.message);
        res.status(500).send("Failed to fetch data range.");
    }
});

app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
});