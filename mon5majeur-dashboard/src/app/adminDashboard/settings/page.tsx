'use client';

import AccountingSettings from '@/components/modules/dashboard/settings/AccountingSettings';
import ContentPageEditor from '@/components/modules/dashboard/settings/ContentPageEditor';
import LegalNotice from '@/components/modules/dashboard/settings/LegalNotice';
import ResetPassword from '@/components/modules/dashboard/settings/ResetPassword';
import SupportCenter from '@/components/modules/dashboard/settings/SupportCenter';
import TermsAndConditions from '@/components/modules/dashboard/settings/TermsAndConditions';
import React, { useState } from 'react';

type Tab = 'accounting' | 'password' | 'legal' | 'terms' | 'about' | 'privacy' | 'support';

const TABS: { key: Tab; label: string }[] = [
  { key: 'accounting', label: 'Accounting Settings' },
  { key: 'password', label: 'Reset Password' },
  { key: 'legal', label: 'Legal Notice' },
  { key: 'terms', label: 'Terms & Conditions' },
  { key: 'about', label: 'About Us' },
  { key: 'privacy', label: 'Privacy Policy' },
  { key: 'support', label: 'Support Center' },
];

export default function SettingsTabs() {
  const [activeTab, setActiveTab] = useState<Tab>('accounting');

  return (
    <div>
      <h1 className='text-[32px] mb-10 font-bold'>Settings</h1>
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4 mb-6">
        {TABS.map((tab) => (
          <button
            key={tab.key}
            onClick={() => setActiveTab(tab.key)}
            className={`px-4 py-2 rounded w-full text-center ${
              activeTab === tab.key
                ? 'bg-[#E8632C] text-white'
                : 'bg-gray-200 text-gray-700'
            }`}
          >
            {tab.label}
          </button>
        ))}
      </div>

      <div className="">
        {activeTab === 'accounting' && <AccountingSettings />}
        {activeTab === 'password' && <ResetPassword />}
        {activeTab === 'legal' && <LegalNotice />}
        {activeTab === 'terms' && <TermsAndConditions />}
        {activeTab === 'about' && <ContentPageEditor slug="about_us" heading="About Us" />}
        {activeTab === 'privacy' && (
          <ContentPageEditor slug="privacy_policy" heading="Privacy Policy" />
        )}
        {activeTab === 'support' && <SupportCenter />}
      </div>
    </div>
  );
}
