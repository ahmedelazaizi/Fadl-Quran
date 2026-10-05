const fs = require('fs');
const formatter = new Intl.DateTimeFormat('en-US-u-ca-islamic-umalqura', {
  timeZone: 'UTC', year: 'numeric', month: 'numeric', day: 'numeric',
});
const months = [];
let previous = '';
for (let date = new Date(Date.UTC(1899, 11, 25)); date < new Date(Date.UTC(2201, 0, 8)); date.setUTCDate(date.getUTCDate() + 1)) {
  const parts = Object.fromEntries(formatter.formatToParts(date).map(part => [part.type, part.value]));
  const id = `${parts.year}-${parts.month}`;
  if (id === previous) continue;
  months.push(`  (${Number(parts.year)}, ${Number(parts.month)}, ${Math.floor(date.getTime() / 86400000)}),`);
  previous = id;
}
fs.writeFileSync('lib/core/umm_al_qura_months.dart', `// Month starts from ICU islamic-umalqura, as used by backend/src/lib/hijri.ts.\n// Entries are (Hijri year, month, Gregorian UTC epoch day).\nconst ummAlQuraMonths = <(int, int, int)>[\n${months.join('\n')}\n];\n`);
