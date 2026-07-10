const fs = require('fs');
let code = fs.readFileSync('src/features/odp/capacity.tsx', 'utf8');

const odcStart = code.indexOf('{/* ODC Backbone Distribution */}');
const chartStart = code.indexOf('<div className=\'grid grid-cols-1 lg:grid-cols-3 gap-6\'>');
const odpStart = code.indexOf('{/* Vertical Stack: Detailed List then Insight */}');
const odpInnerStart = code.indexOf('{/* Detailed List with Professional Pagination */}');
const insightStart = code.indexOf('<Card className=\'border-none shadow-lg bg-card border text-card-foreground\'>');
const endDiv = code.indexOf('</Main>');

if (odcStart === -1 || chartStart === -1 || odpStart === -1 || insightStart === -1) {
    console.log('Failed to find sections');
    process.exit(1);
}

const beforeOdc = code.substring(0, odcStart);
const odcBlock = code.substring(odcStart, chartStart);
const chartBlock = code.substring(chartStart, odpStart);
const odpBlock = code.substring(odpInnerStart, insightStart);
const insightBlock = code.substring(insightStart, code.lastIndexOf('</div>', endDiv));
const afterMain = code.substring(code.lastIndexOf('</div>', endDiv) + 6);

const newCode = beforeOdc +
    chartBlock +
    '\n        {/* Smart Analysis */}\n        ' + insightBlock +
    '\n        {/* Vertical Stack: Detailed Data */}\n        <div className=\'space-y-6\'>\n            ' + 
    odcBlock + '\n            ' + 
    odpBlock +
    '\n        </div>\n    ' + 
    afterMain;

fs.writeFileSync('src/features/odp/capacity.tsx', newCode);
console.log('Success');
