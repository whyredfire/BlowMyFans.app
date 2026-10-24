export const repositoryURL = "https://github.com/whyredfire/BlowMyFans.app";
export const releasesURL = `${repositoryURL}/releases`;
export const translateURL = "https://translate-blowmyfans.whyredfire.dev";
/** Every release names its archive BlowMyFans.zip, so this link always gets the latest. */
export const downloadURL = `${releasesURL}/latest/download/BlowMyFans.zip`;
export const quarantineCommand = 'xattr -dr com.apple.quarantine "/Applications/Blow My Fans.app"';
export const brewCommands = [
  "brew tap whyredfire/blowmyfans https://github.com/whyredfire/BlowMyFans.app",
  "brew install --cask whyredfire/blowmyfans/blow-my-fans",
];
