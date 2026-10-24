import {chromium} from 'playwright';
export {chromium};
export const browserOptions = {headless: true, ...(process.env.CHROMIUM_PATH ? {executablePath: process.env.CHROMIUM_PATH} : {})};
