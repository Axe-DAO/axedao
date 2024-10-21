import axios from 'axios';
import { fileTypeFromBuffer } from 'file-type';
import sharp, { ResizeOptions } from 'sharp';

import { PINATA_FILE_GROUP } from '@/config/constants';
import ENV from '@/config/environment';

type PinningResponse = { cid?: string; error?: string; errorStatus?: ResponseInit['status'] };

export const pinToGroup = async (
  file: File,
  name: string,
  resizeOptions: ResizeOptions | null | undefined = null,
  replaceCID?: string | null,
): Promise<PinningResponse> => {
  const buffer = await file.arrayBuffer();
  const inFileType = await fileTypeFromBuffer(buffer);

  if (
    !inFileType ||
    !['image/png', 'image/jpeg', 'image/jpg', 'image/webp', 'image/svg+xml'].includes(inFileType.mime)
  ) {
    return { error: `Invalid input data. Unsupported image mime-type. ${inFileType?.mime}`, errorStatus: 400 };
  }

  // Image processing (hint: rotate() is used to fix orientation before removing EXIF data)
  const imageBuffer = await sharp(buffer).rotate().resize(resizeOptions).webp({ lossless: true }).toBuffer();

  const uploadData = new FormData();
  uploadData.append('file', new Blob([imageBuffer]));
  uploadData.append('pinataMetadata', JSON.stringify({ name }));
  uploadData.append('pinataOptions', JSON.stringify({ groupId: PINATA_FILE_GROUP }));

  const cid = await axios
    .post('https://api.pinata.cloud/pinning/pinFileToIPFS', uploadData, {
      headers: {
        Authorization: `Bearer ${ENV.pinataJwt}`,
      },
    })
    .then((res) => res.data.IpfsHash)
    .catch((error) => {
      console.error('Unable to upload file to IPFS', error.message);
      throw error;
    });

  // Delete existing file
  if (replaceCID && replaceCID !== cid) {
    await unpin(replaceCID).catch((error) => {
      console.error('Unable to unpin file', error.message);
      // Don't return an error here, as the new file has been uploaded successfully
    });
  }

  return { cid };
};

export const unpin = async (cid: string): Promise<void> => {
  await axios
    .delete(`https://api.pinata.cloud/pinning/unpin/${cid}`, {
      headers: {
        Authorization: `Bearer ${ENV.pinataJwt}`,
      },
    })
    .catch((error) => {
      console.error('Unable to unpin file', error.message);
      throw error;
    });
};
