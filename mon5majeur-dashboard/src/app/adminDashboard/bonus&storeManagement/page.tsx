import BonusManagement from '@/components/modules/dashboard/BonusManagement'
import BounsCard from '@/components/modules/dashboard/BounsCard'
import React from 'react'

export default function page() {
  return (
    <div>
      <h2 className='text-[24px] md:text-[28px] lg:text-[30px] font-semibold'>Bonus & Store Management</h2>
      <p className='text-[14px] md:text-[16px]'>Matches awaiting score verification or dispute resolution.</p>
      
      <BonusManagement></BonusManagement>
    </div>
  )
}
