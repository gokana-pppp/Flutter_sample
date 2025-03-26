import { defineStorage } from '@aws-amplify/backend';

export const storage = defineStorage({
  name: 'FlutterTestApp',
  access: (allow) => ({
    // 特定のフォルダに対するアクセス権限を設定
    'user_images/*': [
      // 認証済みユーザーのみがアクセスできる
      allow.authenticated.to(['read', 'write', 'delete']),
      // ゲストユーザーは読み込みのみ可能
      // allow.guest.to(['read', 'write'])
    ],
    'public/*': [
      // 認証済みユーザーのみがアクセスできる
      allow.authenticated.to(['read', 'write', 'delete']),
      // ゲストユーザーは読み込みのみ可能
      // allow.guest.to(['read'])
    ],
  }),
});