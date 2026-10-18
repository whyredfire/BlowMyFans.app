export const repositoryURL = "https://github.com/whyredfire/Walter.app";
export const releasesURL = `${repositoryURL}/releases`;
/** Every release also carries this unversioned copy, so the link always gets the latest. */
export const downloadURL = `${releasesURL}/latest/download/Walter.zip`;
export const quarantineCommand = "xattr -dr com.apple.quarantine /Applications/Walter.app";
