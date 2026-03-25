require('dotenv').config(); // charge les variables .env
const express = require('express');
const axios = require('axios');
const fs = require('fs/promises');
const path = require('path');
const crypto = require('crypto');

const app = express();
const PORT = 3000;

// fichier JSON utilisé pour stocker l'historique des repas
const MEAL_HISTORY_FILE = path.join(__dirname, 'meal-history.json');

// permet de lire le JSON envoyé par le front
app.use(express.json());

// vérifie que les clés existent
if (!process.env.USDA_API_KEY) {
    throw new Error("USDA_API_KEY manquante dans le fichier .env");
}

/*
    Stockage temporaire des tokens Dexcom (mémoire)
    ⚠️ à remplacer par une base de données en prod
*/
let dexcomTokens = {
    access_token: null,
    refresh_token: null,
    expires_at: null
};

/*
    ===============================
    🔥 Traduction FR -> EN
    ===============================
*/
async function translateToEnglish(text) {
    try {
        const cleanedText = String(text).trim().toLowerCase();

        const response = await axios.get(
            'https://api.mymemory.translated.net/get',
            {
                params: {
                    q: cleanedText,
                    langpair: 'fr|en',
                    de: process.env.MYMEMORY_EMAIL
                }
            }
        );

        const translatedText = response.data?.responseData?.translatedText;

        if (!translatedText || typeof translatedText !== 'string') {
            return cleanedText;
        }

        return translatedText.trim().toLowerCase();
    } catch (error) {
        console.error("Erreur traduction MyMemory :", error.response?.data || error.message);
        return String(text).trim().toLowerCase();
    }
}

/*
    ===============================
    🔥 Calcul de l’impact glycémique
    ===============================
*/
function estimateGlycemicImpact(totals) {
    const carbs = Number(totals.carbohydrates_total_g || 0);
    const fiber = Number(totals.fiber_g || 0);
    const fat = Number(totals.fat_total_g || 0);
    const sugar = Number(totals.sugar_g || 0);

    const netCarbs = Math.max(carbs - fiber, 0);

    let score = netCarbs;
    score += sugar * 0.5;
    score -= fiber * 0.7;
    score -= fat * 0.2;

    let level = "faible";
    let message = "Impact glycémique faible";

    if (score >= 10 && score < 25) {
        level = "modéré";
        message = "Impact glycémique modéré";
    } else if (score >= 25) {
        level = "élevé";
        message = "Impact glycémique élevé";
    }

    return {
        score: Number(score.toFixed(1)),
        level,
        message
    };
}

/*
    ===============================
    🔥 Parseur simple : "100g rice 150g chicken"
    ===============================
    Retourne une liste d'ingrédients avec leur grammage
*/
function parseIngredientsWithGrams(text) {
    const normalized = String(text)
        .toLowerCase()
        .replace(/,/g, '.')
        .replace(/\s+/g, ' ')
        .trim();

    // capture : 100g rice / 150 g chicken / 75g pasta
    const regex = /(\d+(?:\.\d+)?)\s*g\s+([a-zA-Z][a-zA-Z\s-]*?)(?=(?:\s+\d+(?:\.\d+)?\s*g\s+)|$)/g;

    const ingredients = [];
    let match;

    while ((match = regex.exec(normalized)) !== null) {
        const grams = Number(match[1]);
        const name = match[2].trim();

        if (grams > 0 && name) {
            ingredients.push({ name, grams });
        }
    }

    return ingredients;
}

/*
    ===============================
    🔥 USDA search
    ===============================
    Cherche un aliment et retourne le premier résultat
*/
async function searchUSDAFood(query) {
    const response = await axios.post(
        'https://api.nal.usda.gov/fdc/v1/foods/search',
        {
            query,
            pageSize: 1,
            dataType: ['Foundation', 'SR Legacy', 'Survey (FNDDS)']
        },
        {
            params: {
                api_key: process.env.USDA_API_KEY
            },
            headers: {
                'Content-Type': 'application/json'
            }
        }
    );

    return response.data?.foods?.[0] || null;
}

/*
    Détail précis d’un aliment USDA à partir de son fdcId
*/
async function getUSDAFoodDetails(fdcId) {
    const response = await axios.get(
        `https://api.nal.usda.gov/fdc/v1/food/${fdcId}`,
        {
            params: {
                api_key: process.env.USDA_API_KEY
            }
        }
    );

    return response.data;
}

/*
    Extrait les nutriments utiles d’un aliment USDA
*/
function extractUSDANutrients(food) {
    const nutrients = {
        carbohydrates_total_g: 0,
        fat_total_g: 0,
        fiber_g: 0,
        sugar_g: 0,
        protein_g: 0,
        calories: 0
    };

    if (!food?.foodNutrients) return nutrients;

    for (const n of food.foodNutrients) {
        const name = n.nutrient?.name || n.nutrientName;
        const value = Number(n.amount || n.value || 0);

        if (name === 'Carbohydrate, by difference') {
            nutrients.carbohydrates_total_g = value;
        }
        if (name === 'Total lipid (fat)') {
            nutrients.fat_total_g = value;
        }
        if (name === 'Fiber, total dietary') {
            nutrients.fiber_g = value;
        }
        if (name === 'Sugars, total including NLEA') {
            nutrients.sugar_g = value;
        }
        if (name === 'Protein') {
            nutrients.protein_g = value;
        }
        if (name === 'Energy') {
            nutrients.calories = value;
        }
    }

    return nutrients;
}

/*
    Applique un coefficient selon le grammage
*/
function scaleNutrientsByGrams(nutrients, grams) {
    const factor = grams / 100;

    return {
        carbohydrates_total_g: Number((nutrients.carbohydrates_total_g * factor).toFixed(2)),
        fat_total_g: Number((nutrients.fat_total_g * factor).toFixed(2)),
        fiber_g: Number((nutrients.fiber_g * factor).toFixed(2)),
        sugar_g: Number((nutrients.sugar_g * factor).toFixed(2)),
        protein_g: Number((nutrients.protein_g * factor).toFixed(2)),
        calories: Number((nutrients.calories * factor).toFixed(2))
    };
}

/*
    ===============================
    💾 Gestion du fichier JSON
    ===============================
*/

// lit l’historique complet
async function readMealHistory() {
    try {
        const content = await fs.readFile(MEAL_HISTORY_FILE, 'utf-8');
        const parsed = JSON.parse(content);

        return Array.isArray(parsed) ? parsed : [];
    } catch (error) {
        if (error.code === 'ENOENT') {
            return [];
        }
        throw error;
    }
}

// réécrit tout l’historique
async function writeMealHistory(history) {
    await fs.writeFile(
        MEAL_HISTORY_FILE,
        JSON.stringify(history, null, 2),
        'utf-8'
    );
}

// ajoute un repas dans l’historique
async function saveMealRecord(record) {
    const history = await readMealHistory();
    history.push(record);
    await writeMealHistory(history);
}

// génère un id simple pour un repas
function generateMealId() {
    return crypto.randomUUID();
}

/*
    ===============================
    🔥 Fonction centrale d’analyse repas
    ===============================
    Utilisée à la fois pour créer et modifier un repas
*/
async function buildMealAnalysis({ meal_taken_at, foods }) {
    if (!Array.isArray(foods) || foods.length === 0) {
        throw new Error("foods doit être un tableau non vide");
    }

    const mealTakenAt = meal_taken_at || new Date().toISOString();
    const items = [];

    for (const foodItem of foods) {
        const fdcId = Number(foodItem.fdcId);
        const grams = Number(foodItem.grams);

        if (!fdcId || !grams || grams <= 0) {
            items.push({
                fdcId: foodItem.fdcId || null,
                description: foodItem.description || null,
                grams: foodItem.grams || null,
                found: false,
                error: "fdcId ou grammage invalide"
            });
            continue;
        }

        try {
            const foodDetails = await getUSDAFoodDetails(fdcId);
            const rawNutrients = extractUSDANutrients(foodDetails);
            const scaledNutrients = scaleNutrientsByGrams(rawNutrients, grams);

            items.push({
                fdcId,
                description: foodDetails.description || foodItem.description || null,
                grams,
                found: true,
                ...scaledNutrients
            });
        } catch (foodError) {
            console.error(
                `Erreur USDA pour fdcId ${fdcId} :`,
                foodError.response?.data || foodError.message
            );

            items.push({
                fdcId,
                description: foodItem.description || null,
                grams,
                found: false,
                error: "Impossible de récupérer cet aliment"
            });
        }
    }

    const totals = items.reduce((acc, item) => {
        acc.carbohydrates_total_g += Number(item.carbohydrates_total_g || 0);
        acc.fat_total_g += Number(item.fat_total_g || 0);
        acc.fiber_g += Number(item.fiber_g || 0);
        acc.sugar_g += Number(item.sugar_g || 0);
        acc.protein_g += Number(item.protein_g || 0);
        acc.calories += Number(item.calories || 0);
        return acc;
    }, {
        carbohydrates_total_g: 0,
        fat_total_g: 0,
        fiber_g: 0,
        sugar_g: 0,
        protein_g: 0,
        calories: 0
    });

    const netCarbs = Math.max(totals.carbohydrates_total_g - totals.fiber_g, 0);
    const glycemicImpact = estimateGlycemicImpact(totals);

    return {
        meal_taken_at: mealTakenAt,
        items,
        totals: {
            carbohydrates_total_g: Number(totals.carbohydrates_total_g.toFixed(2)),
            fat_total_g: Number(totals.fat_total_g.toFixed(2)),
            fiber_g: Number(totals.fiber_g.toFixed(2)),
            sugar_g: Number(totals.sugar_g.toFixed(2)),
            protein_g: Number(totals.protein_g.toFixed(2)),
            calories: Number(totals.calories.toFixed(2)),
            net_carbs_g: Number(netCarbs.toFixed(2))
        },
        glycemic_impact: glycemicImpact,
        note: "Estimation basée sur les aliments sélectionnés par l'utilisateur et leur grammage."
    };
}

/*
    Redirection vers la page de login Dexcom
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
    Callback après login Dexcom
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

        res.send("Connexion réussie");
    } catch (error) {
        console.error(error.response?.data || error.message);
        res.send("Token exchange failed.");
    }
});

/*
    Vérifie si l’utilisateur est connecté
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
    Rafraîchit le token Dexcom si expiré
*/
async function ensureValidAccessToken() {
    if (!dexcomTokens.access_token) {
        throw new Error("User not authenticated.");
    }

    if (Date.now() < dexcomTokens.expires_at - 60000) {
        return dexcomTokens.access_token;
    }

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

    return dexcomTokens.access_token;
}

/*
    Formate la date au format Dexcom
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
    Récupère les données de glycémie Dexcom
*/
app.get('/dexcom/egvs', async (req, res) => {
    try {
        const accessToken = await ensureValidAccessToken();

        const hours = parseInt(req.query.hours) || 3;

        const now = new Date();
        const startDate = new Date(now.getTime() - hours * 3600000);

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

/*
    ===============================
    🔍 Recherche d’aliments USDA
    ===============================
    Sert à alimenter la liste déroulante du front
*/
app.post('/nutrition/search', async (req, res) => {
    try {
        const { query } = req.body;

        if (!query || typeof query !== 'string') {
            return res.status(400).json({
                error: "query manquante"
            });
        }

        const translatedQuery = await translateToEnglish(query);
        const foods = await searchUSDAFoodList(translatedQuery);

        const results = foods.map(food => ({
            fdcId: food.fdcId,
            description: food.description,
            dataType: food.dataType,
            brandName: food.brandOwner || null
        }));

        res.json({
            original_query: query,
            translated_query: translatedQuery,
            results
        });
    } catch (error) {
        console.error("Erreur /nutrition/search :", error.response?.data || error.message);

        res.status(500).json({
            error: "Erreur dans /nutrition/search",
            details: error.response?.data || error.message
        });
    }
});

/*
    Liste plusieurs résultats USDA
*/
async function searchUSDAFoodList(query) {
    const response = await axios.post(
        'https://api.nal.usda.gov/fdc/v1/foods/search',
        {
            query,
            pageSize: 8,
            dataType: ['Foundation', 'SR Legacy', 'Survey (FNDDS)']
        },
        {
            params: {
                api_key: process.env.USDA_API_KEY
            },
            headers: {
                'Content-Type': 'application/json'
            }
        }
    );

    return response.data?.foods || [];
}

/*
    ===============================
    🍽️ Créer et enregistrer un repas
    ===============================
    Le repas est sauvegardé dès l’envoi de la requête
*/
app.post('/nutrition/analyze-meal', async (req, res) => {
    try {
        const { foods, meal_taken_at } = req.body;

        if (!Array.isArray(foods) || foods.length === 0) {
            return res.status(400).json({
                error: "foods doit être un tableau non vide"
            });
        }

        const analysis = await buildMealAnalysis({
            foods,
            meal_taken_at
        });

        const record = {
            id: generateMealId(),
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
            ...analysis
        };

        await saveMealRecord(record);

        res.json(record);
    } catch (error) {
        console.error("Erreur /nutrition/analyze-meal :", error.response?.data || error.message);

        res.status(500).json({
            error: "Erreur dans /nutrition/analyze-meal",
            details: error.response?.data || error.message
        });
    }
});

/*
    ===============================
    📚 Lire l’historique complet
    ===============================
*/
app.get('/nutrition/history', async (req, res) => {
    try {
        const history = await readMealHistory();
        res.json(history);
    } catch (error) {
        console.error("Erreur /nutrition/history :", error.message);
        res.status(500).json({
            error: "Impossible de lire l'historique"
        });
    }
});

/*
    ===============================
    📄 Lire un repas par son id
    ===============================
*/
app.get('/nutrition/history/:id', async (req, res) => {
    try {
        const history = await readMealHistory();
        const meal = history.find(item => item.id === req.params.id);

        if (!meal) {
            return res.status(404).json({
                error: "Repas introuvable"
            });
        }

        res.json(meal);
    } catch (error) {
        console.error("Erreur /nutrition/history/:id :", error.message);
        res.status(500).json({
            error: "Impossible de lire ce repas"
        });
    }
});

/*
    ===============================
    ✏️ Modifier un repas existant
    ===============================
    On renvoie toute la nouvelle liste d’aliments
    puis on recalcule tout avant sauvegarde
*/
app.put('/nutrition/history/:id', async (req, res) => {
    try {
        const { foods, meal_taken_at } = req.body;
        const mealId = req.params.id;

        if (!Array.isArray(foods) || foods.length === 0) {
            return res.status(400).json({
                error: "foods doit être un tableau non vide"
            });
        }

        const history = await readMealHistory();
        const existingMealIndex = history.findIndex(item => item.id === mealId);

        if (existingMealIndex === -1) {
            return res.status(404).json({
                error: "Repas introuvable"
            });
        }

        const existingMeal = history[existingMealIndex];

        const analysis = await buildMealAnalysis({
            foods,
            meal_taken_at: meal_taken_at || existingMeal.meal_taken_at
        });

        const updatedMeal = {
            id: existingMeal.id,
            created_at: existingMeal.created_at,
            updated_at: new Date().toISOString(),
            ...analysis
        };

        history[existingMealIndex] = updatedMeal;
        await writeMealHistory(history);

        res.json(updatedMeal);
    } catch (error) {
        console.error("Erreur PUT /nutrition/history/:id :", error.response?.data || error.message);

        res.status(500).json({
            error: "Impossible de modifier ce repas",
            details: error.response?.data || error.message
        });
    }
});

/*
    ===============================
    🗑️ Supprimer un repas
    ===============================
*/
app.delete('/nutrition/history/:id', async (req, res) => {
    try {
        const mealId = req.params.id;
        const history = await readMealHistory();

        const existingMeal = history.find(item => item.id === mealId);

        if (!existingMeal) {
            return res.status(404).json({
                error: "Repas introuvable"
            });
        }

        const newHistory = history.filter(item => item.id !== mealId);
        await writeMealHistory(newHistory);

        res.json({
            success: true,
            message: "Repas supprimé",
            deleted_id: mealId
        });
    } catch (error) {
        console.error("Erreur DELETE /nutrition/history/:id :", error.message);

        res.status(500).json({
            error: "Impossible de supprimer ce repas"
        });
    }
});

/*
    Lancement du serveur
*/
app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
});