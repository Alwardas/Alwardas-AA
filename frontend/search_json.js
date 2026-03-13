const fs = require('fs');
const content = fs.readFileSync('assets/data/json/cme.json', 'utf8');
const data = JSON.parse(content);
if (data.lesson_plans && data.lesson_plans['CM-303']) {
    console.log("CM-303 lesson plan found in JSON");
    console.log("Length:", data.lesson_plans['CM-303'].length);
} else {
    console.log("CM-303 NOT found in JSON lesson_plans");
}
