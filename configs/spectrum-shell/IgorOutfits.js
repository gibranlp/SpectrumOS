.pragma library

var outfits = [
    { id: "day-of-the-dead", month: 11, days: [1, 2], asset: "day-of-the-dead-mask.svg" },
    { id: "christmas", month: 12, days: [25], asset: "santa-hat.svg" },
    { id: "christmas-lights", month: 12, probability: 0.5, asset: "christmas-lights.svg" }
];

function forDate(date, roll = 1) {
    for (const outfit of outfits) {
        if (date.getMonth() + 1 === outfit.month
                && (!outfit.days || outfit.days.indexOf(date.getDate()) !== -1)
                && (outfit.probability === undefined || roll < outfit.probability))
            return outfit;
    }
    return null;
}
