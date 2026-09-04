/**
 * Cloudflare R2 存储服务。
 * R2 兼容 S3 API，使用 account ID 生成 S3 endpoint，使用公开域名访问对象。
 */
import {
  DeleteObjectCommand,
  PutObjectCommand,
  S3Client,
} from "@aws-sdk/client-s3";
import { SiteSetting } from "../models";

export interface R2Config {
  enabled: boolean;
  accountId: string;
  accessKeyId: string;
  secretAccessKey: string;
  bucket: string;
  publicDomain: string;
  path: string;
  endpoint: string;
}

function cleanDomain(value: string): string {
  const domain = value.trim().replace(/\/+$/, "");
  if (!domain) return "";
  return /^https?:\/\//i.test(domain) ? domain : `https://${domain}`;
}

export async function getR2Config(): Promise<R2Config> {
  const setting = await SiteSetting.findByPk(1);
  const accountId = (setting?.r2AccountId || "").trim();
  return {
    enabled: !!setting?.r2Enabled,
    accountId,
    accessKeyId: (setting?.r2AccessKeyId || "").trim(),
    secretAccessKey: setting?.r2SecretAccessKey || "",
    bucket: (setting?.r2Bucket || "").trim(),
    publicDomain: cleanDomain(setting?.r2PublicDomain || ""),
    path: (setting?.r2Path || "").replace(/^\/+|\/+$/g, ""),
    endpoint: accountId ? `https://${accountId}.r2.cloudflarestorage.com` : "",
  };
}

export function isR2ConfigReady(config: R2Config): boolean {
  return Boolean(
    config.enabled &&
      config.accountId &&
      config.accessKeyId &&
      config.secretAccessKey &&
      config.bucket &&
      config.publicDomain
  );
}

export async function isR2Ready(): Promise<boolean> {
  return isR2ConfigReady(await getR2Config());
}

function createClient(config: R2Config): S3Client {
  return new S3Client({
    region: "auto",
    endpoint: config.endpoint,
    forcePathStyle: true,
    credentials: {
      accessKeyId: config.accessKeyId,
      secretAccessKey: config.secretAccessKey,
    },
  });
}

function publicUrl(config: R2Config, key: string): string {
  const encodedKey = key
    .split("/")
    .map((part) => encodeURIComponent(part))
    .join("/");
  return `${config.publicDomain}/${encodedKey}`;
}

export async function uploadToR2(
  buffer: Buffer,
  key: string,
  contentType: string
): Promise<string> {
  const config = await getR2Config();
  if (!isR2ConfigReady(config)) {
    throw new Error("Cloudflare R2 未启用或配置不完整");
  }

  const cleanKey = key.replace(/^\/+/, "");
  try {
    await createClient(config).send(
      new PutObjectCommand({
        Bucket: config.bucket,
        Key: cleanKey,
        Body: buffer,
        ContentType: contentType || "application/octet-stream",
        CacheControl: "public, max-age=31536000, immutable",
      })
    );
    return publicUrl(config, cleanKey);
  } catch (error: any) {
    throw new Error(`Cloudflare R2 上传失败: ${error?.message || "网络错误"}`);
  }
}

export async function deleteFromR2(key: string): Promise<boolean> {
  const config = await getR2Config();
  if (!isR2ConfigReady(config)) return false;

  await createClient(config).send(
    new DeleteObjectCommand({
      Bucket: config.bucket,
      Key: key.replace(/^\/+/, ""),
    })
  );
  return true;
}

/** 从公开 URL 中提取 R2 对象 key。 */
export function extractR2Key(url: string): string {
  try {
    const pathname = new URL(url).pathname.replace(/^\/+/, "");
    return decodeURIComponent(pathname);
  } catch {
    return url.replace(/^\/+/, "");
  }
}

/** 上传并删除一个临时对象，用于后台测试凭据和桶权限。 */
export async function testR2Connection(): Promise<{ url: string }> {
  const config = await getR2Config();
  if (!isR2ConfigReady(config)) {
    throw new Error("Cloudflare R2 未启用或配置不完整（需要启用、Account ID、Access Key、Secret Key、Bucket 和公开访问域名）");
  }

  const key = `kanle-test/connection-${Date.now()}.txt`;
  const client = createClient(config);
  try {
    await client.send(
      new PutObjectCommand({
        Bucket: config.bucket,
        Key: key,
        Body: Buffer.from("kanle-r2-connection-test"),
        ContentType: "text/plain",
      })
    );
    return { url: publicUrl(config, key) };
  } catch (error: any) {
    throw new Error(`Cloudflare R2 连接失败: ${error?.message || "网络错误"}`);
  } finally {
    try {
      await client.send(new DeleteObjectCommand({ Bucket: config.bucket, Key: key }));
    } catch {
      // 测试对象清理失败不覆盖原始连接错误。
    }
  }
}
