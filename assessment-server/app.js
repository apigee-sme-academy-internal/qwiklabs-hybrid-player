const express = require('express')
const app = express()
const port = 80

const at = require('./at.js')

app.get('/date', async (req, res) => {
    const date = await at.date();

    res.send( date )
})


app.get('/kubectl', async (req, res) => {
    const kubectl = await at.kubectl();

    res.send( kubectl )
})

app.get('/', (req, res) => res.send('Hello World!'))

app.listen(port, '0.0.0.0', () => console.log(`assessment-server listening at http://0.0.0.0`))